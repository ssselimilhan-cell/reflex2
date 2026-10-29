import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../main.dart' show firebaseAvailable;
import 'app_settings.dart';
import 'strings.dart';
import 'telemetry.dart';
import 'user_profile.dart';

/// Oturum başına en fazla 3 geri bildirim (kötüye kullanım/maliyet sınırı).
int _sentThisSession = 0;

/// Play Store mağaza sayfasını açar (yayında değilse sessizce yok sayılır).
Future<void> openStoreReview() async {
  Telemetry.log('rate_app');
  try {
    await InAppReview.instance.openStoreListing();
  } catch (_) {}
}

/// Geri bildirimi kendi Firestore'umuza yazar (koleksiyon: feedback).
/// Kayıtları yalnızca sen Firebase Console'dan okursun.
/// Başarılıysa 'ok', değilse kısa bir hata kodu döner:
///  - firebase-init: Firebase başlatılamadı (online özellikler de çalışmaz)
///  - limit: oturum başına 3 gönderim sınırı
///  - permission-denied: Firestore kuralı yazmaya izin vermiyor
///  - timeout: sunucudan 15 sn içinde yanıt gelmedi (yazma sıraya alınır)
Future<String> submitFeedback(String type, String message) async {
  if (!firebaseAvailable) return 'firebase-init';
  if (_sentThisSession >= 3) return 'limit';
  try {
    await FirebaseFirestore.instance.collection('feedback').add({
      'type': type,
      'message': message.length > 500 ? message.substring(0, 500) : message,
      'deviceId': UserProfile.instance.deviceId,
      'lang': AppSettings.instance.language.name,
      'appVersion': Telemetry.appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 15));
    _sentThisSession++;
    Telemetry.log('feedback_sent', {'type': type});
    return 'ok';
  } on TimeoutException {
    return 'timeout';
  } on FirebaseException catch (e) {
    return e.code;
  } catch (_) {
    return 'error';
  }
}

/// Ayarlar'dan açılan "Geri bildirim gönder" penceresi.
Future<void> showFeedbackDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = TextEditingController();
  var type = 'idea';
  var sending = false;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(t('feedback_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final k in const ['bug', 'idea', 'other'])
                    ChoiceChip(
                      label: Text(t('feedback_type_$k')),
                      selected: type == k,
                      onSelected: (_) => setState(() => type = k),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 500,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: t('feedback_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: sending ? null : () => Navigator.pop(dialogContext),
            child: Text(t('feedback_cancel')),
          ),
          ElevatedButton(
            onPressed: sending
                ? null
                : () async {
                    final text = controller.text.trim();
                    if (text.length < 5) return;
                    setState(() => sending = true);
                    final ok = await submitFeedback(type, text);
                    if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
                  },
            child: Text(t('feedback_send')),
          ),
        ],
      ),
    ),
  );
  if (result == null) return;
  final String text;
  if (result == 'ok') {
    text = t('feedback_thanks');
  } else if (result == 'timeout') {
    text = '${t('feedback_queued')} ($result)';
  } else {
    text = '${t('feedback_failed')} ($result)';
  }
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
