import 'app_settings.dart';

const Map<String, Map<String, String>> _strings = {
  'app_title': {'tr': 'STRES', 'en': 'STRES'},
  'app_subtitle': {'tr': 'Refleks Kart Oyunu', 'en': 'Reflex Card Game'},
  'menu_local': {
    'tr': '2 Kişilik (Aynı Cihaz)',
    'en': '2 Player (Same Device)'
  },
  'menu_bot': {'tr': 'Bilgisayara Karşı', 'en': 'Vs Computer'},
  'menu_online': {'tr': 'Online Oyna', 'en': 'Play Online'},
  'menu_settings': {'tr': 'Ayarlar', 'en': 'Settings'},
  'settings_title': {'tr': 'Ayarlar', 'en': 'Settings'},
  'settings_card_size': {'tr': 'Kart Boyutu', 'en': 'Card Size'},
  'settings_font_size': {'tr': 'Yazı Boyutu', 'en': 'Font Size'},
  'settings_color': {'tr': 'Arka Plan Rengi', 'en': 'Background Color'},
  'settings_card_back': {'tr': 'Kart Arkası Rengi', 'en': 'Card Back Color'},
  'settings_animation_speed': {
    'tr': 'Açılış Animasyon Hızı',
    'en': 'Reveal Animation Speed'
  },
  'settings_high_contrast': {
    'tr': 'Yüksek Kontrast (Aktif Kartlar)',
    'en': 'High Contrast (Active Cards)'
  },
  'settings_language': {'tr': 'Dil', 'en': 'Language'},
  'speed_fast': {'tr': 'Hızlı', 'en': 'Fast'},
  'speed_normal': {'tr': 'Normal', 'en': 'Normal'},
  'speed_slow': {'tr': 'Yavaş', 'en': 'Slow'},
  'no_match': {'tr': 'Benzer Kalmadı', 'en': 'No Matches Left'},
  'play_again': {'tr': 'Tekrar Oyna', 'en': 'Play Again'},
  'you_won': {'tr': 'Kazandın!', 'en': 'You Won!'},
  'bot_won': {'tr': 'Bot Kazandı!', 'en': 'Computer Won!'},
  'p1_won': {'tr': 'Oyuncu 1 Kazandı!', 'en': 'Player 1 Won!'},
  'p2_won': {'tr': 'Oyuncu 2 Kazandı!', 'en': 'Player 2 Won!'},
  'difficulty': {'tr': 'Zorluk', 'en': 'Difficulty'},
  'pause': {'tr': 'Duraklat', 'en': 'Pause'},
  'resume': {'tr': 'Devam Et', 'en': 'Resume'},
  'paused': {'tr': 'Duraklatıldı', 'en': 'Paused'},
  'you': {'tr': 'Sen', 'en': 'You'},
  'bot': {'tr': 'Bot', 'en': 'Bot'},
  'player1': {'tr': 'Oyuncu 1', 'en': 'Player 1'},
  'player2': {'tr': 'Oyuncu 2', 'en': 'Player 2'},
  'stock': {'tr': 'Kaynak', 'en': 'Stock'},
  'score': {'tr': 'Skor', 'en': 'Score'},
  'waiting_opponent': {'tr': 'Rakip bekleniyor…', 'en': 'Waiting for opponent…'},
  'share_code': {'tr': 'Oda kodunu paylaş', 'en': 'Share room code'},
  'room': {'tr': 'Oda', 'en': 'Room'},
  'win': {'tr': 'Kazandın!', 'en': 'You Won!'},
  'lose': {'tr': 'Kaybettin!', 'en': 'You Lost!'},
  'firebase_needed': {
    'tr': 'Online mod için önce Firebase kurulumu tamamlanmalı.',
    'en': 'Online mode requires Firebase setup first.'
  },
  'new_room': {'tr': 'Yeni Oda Kur', 'en': 'Create New Room'},
  'join_room': {'tr': 'Odaya Katıl', 'en': 'Join Room'},
  'room_code_hint': {'tr': 'ODA KODU', 'en': 'ROOM CODE'},
  'room_not_found': {'tr': 'Oda bulunamadı veya dolu.', 'en': 'Room not found or full.'},
  'or': {'tr': '— veya —', 'en': '— or —'},
  'not_found_closed': {
    'tr': 'Oda bulunamadı ya da kapatıldı.',
    'en': 'Room not found or closed.'
  },
  'opponent': {'tr': 'Rakip', 'en': 'Opponent'},
  'start_game': {'tr': 'Oyunu Başlat', 'en': 'Start Game'},
  'opponent_connected': {'tr': 'Rakip bağlandı!', 'en': 'Opponent connected!'},
  'press_start_hint': {
    'tr': 'Hazır olduğunda başlat.',
    'en': 'Press start when you\'re ready.'
  },
  'waiting_for_accept': {
    'tr': 'Rakibin kabul etmesi bekleniyor…',
    'en': 'Waiting for opponent to accept…'
  },
  'opponent_wants_start': {
    'tr': 'Rakip oyunu başlatmak istiyor!',
    'en': 'Opponent wants to start the game!'
  },
  'accept': {'tr': 'Kabul Et', 'en': 'Accept'},
  'decline': {'tr': 'Reddet', 'en': 'Decline'},
  'cancel_request': {'tr': 'İptal Et', 'en': 'Cancel'},
  'profile': {'tr': 'Profil', 'en': 'Profile'},
  'create_profile': {'tr': 'Profil Oluştur', 'en': 'Create Profile'},
  'guest_playing': {'tr': 'Misafir olarak oynuyorsun', 'en': 'Playing as guest'},
  'display_name': {'tr': 'Görünen Ad', 'en': 'Display Name'},
  'save': {'tr': 'Kaydet', 'en': 'Save'},
  'online_win_rate': {'tr': 'Online Kazanma Oranı', 'en': 'Online Win Rate'},
  'games_played': {'tr': 'Oynanan', 'en': 'Played'},
  'wins': {'tr': 'Galibiyet', 'en': 'Wins'},
  'losses': {'tr': 'Mağlubiyet', 'en': 'Losses'},
  'delete_profile': {
    'tr': 'Profili Sil (Misafir Ol)',
    'en': 'Delete Profile (Go Guest)'
  },
  'enter_name_hint': {'tr': 'Adını yaz', 'en': 'Enter your name'},
  'no_games_yet': {'tr': 'Henüz oyun oynanmadı', 'en': 'No games played yet'},
  'play_as_guest': {'tr': 'Misafir Olarak Devam Et', 'en': 'Continue as Guest'},
};

String t(String key) {
  final lang = AppSettings.instance.language == AppLanguage.en ? 'en' : 'tr';
  return _strings[key]?[lang] ?? key;
}
