#!/usr/bin/env bash
# Play Store yayını için Android ayarlarını tek seferde hazırlar:
#   - uygulama adını (mağazada/telefonda görünen) değiştirir
#   - paket adını (applicationId) değiştirir  (com.example.* Play Store'da kabul edilmez)
#   - RELEASE yapıda internet iznini ekler     (yoksa online mod yayın sürümünde ÇALIŞMAZ)
#   - yayın imzası (key.properties) ayarını ekler
#
# Kullanım (proje klasöründe):
#   bash tools/prepare_android_release.sh "STRES - Refleks Kart Oyunu" com.seninadin.stres
#
# Güvenli: değiştirdiği her dosyanın yanına bir .bak-release yedeği bırakır,
# iki kez çalıştırılırsa aynı şeyi ikinci kez eklemez.
set -euo pipefail

APP_NAME="${1:-}"
APP_ID="${2:-}"
ROOT="${PROJECT_ROOT:-$(pwd)}"
MANIFEST="$ROOT/android/app/src/main/AndroidManifest.xml"

fail() { echo "HATA: $*" >&2; exit 1; }

[ -n "$APP_NAME" ] && [ -n "$APP_ID" ] || fail "kullanım: bash tools/prepare_android_release.sh \"Uygulama Adı\" com.seninadin.stres"
case "$APP_NAME" in *\"*|*\<*|*\>*|*\&*) fail "uygulama adında \" < > & karakterleri olmamalı";; esac
echo "$APP_ID" | grep -Eq '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$' || fail "paket adı geçersiz (örn. com.seninadin.stres — küçük harf, rakam, nokta)"
case "$APP_ID" in com.example.*|com.android.*) fail "paket adı com.example / com.android ile başlayamaz";; esac

if [ -f "$ROOT/android/app/build.gradle.kts" ]; then GRADLE="$ROOT/android/app/build.gradle.kts"; KTS=1
elif [ -f "$ROOT/android/app/build.gradle" ]; then GRADLE="$ROOT/android/app/build.gradle"; KTS=0
else fail "android/app/build.gradle(.kts) bulunamadı — proje klasöründe misin?"; fi
[ -f "$MANIFEST" ] || fail "AndroidManifest.xml bulunamadı"

backup() { [ -f "$1.bak-release" ] || cp "$1" "$1.bak-release"; }
backup "$MANIFEST"; backup "$GRADLE"

# 1) Uygulama adı
grep -q 'android:label="' "$MANIFEST" || fail "manifest içinde android:label bulunamadı"
ESC_NAME=$(printf '%s' "$APP_NAME" | sed -e 's/[&|\\]/\\&/g')
sed -i "s|android:label=\"[^\"]*\"|android:label=\"$ESC_NAME\"|" "$MANIFEST"
echo "✓ Uygulama adı: $APP_NAME"

# 2) Paket adı (namespace bilerek DEĞİŞTİRİLMİYOR; kod yapısı bozulmasın)
if [ "$KTS" = 1 ]; then
  sed -i -E "s|applicationId[ ]*=[ ]*\"[^\"]*\"|applicationId = \"$APP_ID\"|" "$GRADLE"
else
  sed -i -E "s|applicationId[ =]+[\"'][^\"']*[\"']|applicationId \"$APP_ID\"|" "$GRADLE"
fi
grep -q "$APP_ID" "$GRADLE" || fail "applicationId değiştirilemedi — build.gradle'ı elle kontrol et"
echo "✓ Paket adı (applicationId): $APP_ID"

# 3) İnternet izni (yayın sürümünde şart)
if grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  echo "✓ İnternet izni zaten var"
else
  TMP=$(mktemp)
  awk 'BEGIN{d=0} {print} !d && /<manifest/ && />[[:space:]]*$/ {print "    <uses-permission android:name=\"android.permission.INTERNET\"/>"; d=1}' "$MANIFEST" > "$TMP"
  grep -q 'android.permission.INTERNET' "$TMP" || fail "internet izni eklenemedi — AndroidManifest.xml'e elle ekle: <uses-permission android:name=\"android.permission.INTERNET\"/>"
  mv "$TMP" "$MANIFEST"
  echo "✓ İnternet izni eklendi"
fi

# 4) Yayın imzası
if grep -q 'keystoreProperties' "$GRADLE"; then
  echo "✓ İmza ayarı zaten var"
else
  PRE=$(mktemp); POST=$(mktemp); TMP=$(mktemp)
  if [ "$KTS" = 1 ]; then
    cat > "$PRE" << 'KTS_PRE'
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

KTS_PRE
    cat > "$POST" << 'KTS_POST'
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
KTS_POST
    { printf 'import java.util.Properties\nimport java.io.FileInputStream\n\n'; cat "$GRADLE"; } > "$TMP"
    cp "$TMP" "$GRADLE"
    sed -i 's|signingConfigs.getByName("debug")|signingConfigs.getByName("release")|' "$GRADLE"
  else
    cat > "$PRE" << 'GR_PRE'
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

GR_PRE
    cat > "$POST" << 'GR_POST'
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
GR_POST
    sed -i 's|signingConfig signingConfigs.debug|signingConfig signingConfigs.release|' "$GRADLE"
  fi
  awk -v pre="$PRE" -v post="$POST" '
    /^android[ ]*\{/ && !d { while ((getline l < pre) > 0) print l; print; while ((getline l < post) > 0) print l; d=1; next }
    { print }' "$GRADLE" > "$TMP"
  grep -q 'signingConfigs' "$TMP" && grep -q 'keystoreProperties' "$TMP" || fail "imza ayarı eklenemedi — RELEASE_GUIDE.md'deki elle yöntemi kullan"
  cp "$TMP" "$GRADLE"
  echo "✓ Yayın imzası ayarı eklendi (android/key.properties dosyasını okuyacak)"
fi

echo
echo "Hazır. Sıradaki adımlar için store/RELEASE_GUIDE.md dosyasına bak."
