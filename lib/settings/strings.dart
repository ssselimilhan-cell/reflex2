import 'app_settings.dart';

const Map<String, Map<String, String>> _strings = {
  'app_title': {'tr': 'STRES', 'en': 'STRES', 'ru': 'STRES', 'zh': 'STRES'},
  'app_subtitle': {
    'tr': 'Refleks Kart Oyunu',
    'en': 'Reflex Card Game',
    'ru': 'Карточная игра на реакцию',
    'zh': '反应力纸牌游戏'
  },
  'menu_local': {
    'tr': '2 Kişilik (Aynı Cihaz)',
    'en': '2 Player (Same Device)',
    'ru': '2 игрока (одно устройство)',
    'zh': '双人对战（同一设备）'
  },
  'menu_bot': {
    'tr': 'Bilgisayara Karşı',
    'en': 'Vs Computer',
    'ru': 'Против компьютера',
    'zh': '对战电脑'
  },
  'menu_online': {
    'tr': 'Online Oyna',
    'en': 'Play Online',
    'ru': 'Играть онлайн',
    'zh': '在线对战'
  },
  'menu_settings': {'tr': 'Ayarlar', 'en': 'Settings', 'ru': 'Настройки', 'zh': '设置'},
  'settings_title': {'tr': 'Ayarlar', 'en': 'Settings', 'ru': 'Настройки', 'zh': '设置'},
  'settings_card_size': {
    'tr': 'Kart Boyutu',
    'en': 'Card Size',
    'ru': 'Размер карт',
    'zh': '卡牌大小'
  },
  'settings_font_size': {
    'tr': 'Yazı Boyutu',
    'en': 'Font Size',
    'ru': 'Размер текста',
    'zh': '字体大小'
  },
  'settings_color': {
    'tr': 'Arka Plan Rengi',
    'en': 'Background Color',
    'ru': 'Цвет фона',
    'zh': '背景颜色'
  },
  'settings_card_back': {
    'tr': 'Kart Arkası Rengi',
    'en': 'Card Back Color',
    'ru': 'Цвет рубашки карты',
    'zh': '卡背颜色'
  },
  'settings_animation_speed': {
    'tr': 'Açılış Animasyon Hızı',
    'en': 'Reveal Animation Speed',
    'ru': 'Скорость анимации раздачи',
    'zh': '发牌动画速度'
  },
  'settings_high_contrast': {
    'tr': 'Yüksek Kontrast (Aktif Kartlar)',
    'en': 'High Contrast (Active Cards)',
    'ru': 'Высокий контраст (активные карты)',
    'zh': '高对比度（激活的牌）'
  },
  'settings_language': {'tr': 'Dil', 'en': 'Language', 'ru': 'Язык', 'zh': '语言'},
  'settings_card_theme': {
    'tr': 'Kart Teması',
    'en': 'Card Theme',
    'ru': 'Тема карт',
    'zh': '卡牌主题'
  },
  'theme_classic': {'tr': 'İskambil', 'en': 'Classic', 'ru': 'Классика', 'zh': '经典'},
  'theme_fruit': {'tr': 'Meyve', 'en': 'Fruit', 'ru': 'Фрукты', 'zh': '水果'},
  'theme_figure': {'tr': 'Figür', 'en': 'Figure', 'ru': 'Персонажи', 'zh': '人物'},
  'speed_fast': {'tr': 'Hızlı', 'en': 'Fast', 'ru': 'Быстро', 'zh': '快'},
  'speed_normal': {'tr': 'Normal', 'en': 'Normal', 'ru': 'Обычно', 'zh': '正常'},
  'speed_slow': {'tr': 'Yavaş', 'en': 'Slow', 'ru': 'Медленно', 'zh': '慢'},
  'no_match': {
    'tr': 'Benzer Kalmadı',
    'en': 'No Matches Left',
    'ru': 'Совпадений не осталось',
    'zh': '没有匹配的牌了'
  },
  'play_again': {
    'tr': 'Tekrar Oyna',
    'en': 'Play Again',
    'ru': 'Играть снова',
    'zh': '再玩一次'
  },
  'you_won': {'tr': 'Kazandın!', 'en': 'You Won!', 'ru': 'Ты выиграл!', 'zh': '你赢了！'},
  'bot_won': {
    'tr': 'Bot Kazandı!',
    'en': 'Computer Won!',
    'ru': 'Компьютер выиграл!',
    'zh': '电脑赢了！'
  },
  'p1_won': {
    'tr': 'Oyuncu 1 Kazandı!',
    'en': 'Player 1 Won!',
    'ru': 'Игрок 1 выиграл!',
    'zh': '玩家1获胜！'
  },
  'p2_won': {
    'tr': 'Oyuncu 2 Kazandı!',
    'en': 'Player 2 Won!',
    'ru': 'Игрок 2 выиграл!',
    'zh': '玩家2获胜！'
  },
  'difficulty': {'tr': 'Zorluk', 'en': 'Difficulty', 'ru': 'Сложность', 'zh': '难度'},
  'pause': {'tr': 'Duraklat', 'en': 'Pause', 'ru': 'Пауза', 'zh': '暂停'},
  'resume': {'tr': 'Devam Et', 'en': 'Resume', 'ru': 'Продолжить', 'zh': '继续'},
  'paused': {'tr': 'Duraklatıldı', 'en': 'Paused', 'ru': 'Пауза', 'zh': '已暂停'},
  'you': {'tr': 'Sen', 'en': 'You', 'ru': 'Ты', 'zh': '你'},
  'bot': {'tr': 'Bot', 'en': 'Bot', 'ru': 'Бот', 'zh': '电脑'},
  'player1': {'tr': 'Oyuncu 1', 'en': 'Player 1', 'ru': 'Игрок 1', 'zh': '玩家1'},
  'player2': {'tr': 'Oyuncu 2', 'en': 'Player 2', 'ru': 'Игрок 2', 'zh': '玩家2'},
  'stock': {'tr': 'Kaynak', 'en': 'Stock', 'ru': 'Колода', 'zh': '底牌'},
  'score': {'tr': 'Skor', 'en': 'Score', 'ru': 'Счёт', 'zh': '比分'},
  'waiting_opponent': {
    'tr': 'Rakip bekleniyor…',
    'en': 'Waiting for opponent…',
    'ru': 'Ожидание соперника…',
    'zh': '等待对手…'
  },
  'share_code': {
    'tr': 'Oda kodunu paylaş',
    'en': 'Share room code',
    'ru': 'Поделись кодом комнаты',
    'zh': '分享房间号'
  },
  'room': {'tr': 'Oda', 'en': 'Room', 'ru': 'Комната', 'zh': '房间'},
  'win': {'tr': 'Kazandın!', 'en': 'You Won!', 'ru': 'Ты выиграл!', 'zh': '你赢了！'},
  'lose': {'tr': 'Kaybettin!', 'en': 'You Lost!', 'ru': 'Ты проиграл!', 'zh': '你输了！'},
  'firebase_needed': {
    'tr': 'Online mod için önce Firebase kurulumu tamamlanmalı.',
    'en': 'Online mode requires Firebase setup first.',
    'ru': 'Для онлайн-режима сначала нужно настроить Firebase.',
    'zh': '在线模式需要先完成 Firebase 设置。'
  },
  'new_room': {
    'tr': 'Yeni Oda Kur',
    'en': 'Create New Room',
    'ru': 'Создать комнату',
    'zh': '创建房间'
  },
  'join_room': {
    'tr': 'Odaya Katıl',
    'en': 'Join Room',
    'ru': 'Присоединиться',
    'zh': '加入房间'
  },
  'room_code_hint': {
    'tr': 'ODA KODU',
    'en': 'ROOM CODE',
    'ru': 'КОД КОМНАТЫ',
    'zh': '房间号'
  },
  'room_not_found': {
    'tr': 'Oda bulunamadı veya dolu.',
    'en': 'Room not found or full.',
    'ru': 'Комната не найдена или уже заполнена.',
    'zh': '未找到房间或房间已满。'
  },
  'or': {'tr': '— veya —', 'en': '— or —', 'ru': '— или —', 'zh': '— 或者 —'},
  'not_found_closed': {
    'tr': 'Oda bulunamadı ya da kapatıldı.',
    'en': 'Room not found or closed.',
    'ru': 'Комната не найдена или закрыта.',
    'zh': '未找到房间或房间已关闭。'
  },
  'opponent': {'tr': 'Rakip', 'en': 'Opponent', 'ru': 'Соперник', 'zh': '对手'},
  'start_game': {
    'tr': 'Oyunu Başlat',
    'en': 'Start Game',
    'ru': 'Начать игру',
    'zh': '开始游戏'
  },
  'opponent_connected': {
    'tr': 'Rakip bağlandı!',
    'en': 'Opponent connected!',
    'ru': 'Соперник подключился!',
    'zh': '对手已连接！'
  },
  'press_start_hint': {
    'tr': 'Hazır olduğunda başlat.',
    'en': 'Press start when you\'re ready.',
    'ru': 'Нажми «Начать», когда будешь готов.',
    'zh': '准备好后点击开始。'
  },
  'waiting_for_accept': {
    'tr': 'Rakibin kabul etmesi bekleniyor…',
    'en': 'Waiting for opponent to accept…',
    'ru': 'Ожидание подтверждения соперника…',
    'zh': '等待对手接受…'
  },
  'opponent_wants_start': {
    'tr': 'Rakip oyunu başlatmak istiyor!',
    'en': 'Opponent wants to start the game!',
    'ru': 'Соперник хочет начать игру!',
    'zh': '对手想要开始游戏！'
  },
  'accept': {'tr': 'Kabul Et', 'en': 'Accept', 'ru': 'Принять', 'zh': '接受'},
  'decline': {'tr': 'Reddet', 'en': 'Decline', 'ru': 'Отклонить', 'zh': '拒绝'},
  'cancel_request': {'tr': 'İptal Et', 'en': 'Cancel', 'ru': 'Отменить', 'zh': '取消'},
  'profile': {'tr': 'Profil', 'en': 'Profile', 'ru': 'Профиль', 'zh': '个人资料'},
  'create_profile': {
    'tr': 'Profil Oluştur',
    'en': 'Create Profile',
    'ru': 'Создать профиль',
    'zh': '创建个人资料'
  },
  'guest_playing': {
    'tr': 'Misafir olarak oynuyorsun',
    'en': 'Playing as guest',
    'ru': 'Ты играешь как гость',
    'zh': '你正以访客身份游戏'
  },
  'display_name': {
    'tr': 'Görünen Ad',
    'en': 'Display Name',
    'ru': 'Отображаемое имя',
    'zh': '显示名称'
  },
  'save': {'tr': 'Kaydet', 'en': 'Save', 'ru': 'Сохранить', 'zh': '保存'},
  'online_win_rate': {
    'tr': 'Online Kazanma Oranı',
    'en': 'Online Win Rate',
    'ru': 'Процент побед онлайн',
    'zh': '在线胜率'
  },
  'games_played': {'tr': 'Oynanan', 'en': 'Played', 'ru': 'Сыграно', 'zh': '已玩场次'},
  'wins': {'tr': 'Galibiyet', 'en': 'Wins', 'ru': 'Победы', 'zh': '胜场'},
  'losses': {'tr': 'Mağlubiyet', 'en': 'Losses', 'ru': 'Поражения', 'zh': '负场'},
  'delete_profile': {
    'tr': 'Profili Sil (Misafir Ol)',
    'en': 'Delete Profile (Go Guest)',
    'ru': 'Удалить профиль (стать гостем)',
    'zh': '删除资料（变为访客）'
  },
  'enter_name_hint': {
    'tr': 'Adını yaz',
    'en': 'Enter your name',
    'ru': 'Введи своё имя',
    'zh': '输入你的名字'
  },
  'no_games_yet': {
    'tr': 'Henüz oyun oynanmadı',
    'en': 'No games played yet',
    'ru': 'Игр ещё не было',
    'zh': '还没有游戏记录'
  },
  'play_as_guest': {
    'tr': 'Misafir Olarak Devam Et',
    'en': 'Continue as Guest',
    'ru': 'Продолжить как гость',
    'zh': '以访客身份继续'
  },
  'choose_avatar': {
    'tr': 'Avatar Seç',
    'en': 'Choose Avatar',
    'ru': 'Выбрать аватар',
    'zh': '选择头像'
  },
  'chat_hint': {
    'tr': 'Mesaj yaz…',
    'en': 'Type a message…',
    'ru': 'Введите сообщение…',
    'zh': '输入消息…'
  },
  'lobby_title': {'tr': 'Lobi', 'en': 'Lobby', 'ru': 'Лобби', 'zh': '大厅'},
  'open_tables': {
    'tr': 'Açık Masalar',
    'en': 'Open Tables',
    'ru': 'Открытые столы',
    'zh': '开放桌位'
  },
  'no_open_tables': {
    'tr': 'Şu anda açık masa yok',
    'en': 'No open tables right now',
    'ru': 'Сейчас нет открытых столов',
    'zh': '目前没有开放的桌位'
  },
  'guest_label': {'tr': 'Misafir', 'en': 'Guest', 'ru': 'Гость', 'zh': '访客'},
  'join_short': {'tr': 'Katıl', 'en': 'Join', 'ru': 'Войти', 'zh': '加入'},
  'manual_join_title': {
    'tr': 'Kod ile Katıl',
    'en': 'Join by Code',
    'ru': 'Войти по коду',
    'zh': '通过房间号加入'
  },
  'choose_from_gallery': {
    'tr': 'Galeriden Seç',
    'en': 'Choose from Gallery',
    'ru': 'Выбрать из галереи',
    'zh': '从相册选择'
  },
  'remove_photo': {
    'tr': 'Fotoğrafı Kaldır',
    'en': 'Remove Photo',
    'ru': 'Удалить фото',
    'zh': '移除照片'
  },
  'players_title': {'tr': 'Oyuncular', 'en': 'Players', 'ru': 'Игроки', 'zh': '玩家'},
  'sort_alpha': {
    'tr': 'Alfabetik',
    'en': 'Alphabetical',
    'ru': 'По алфавиту',
    'zh': '按字母'
  },
  'sort_games': {
    'tr': 'Oyun Sayısı',
    'en': 'Games Played',
    'ru': 'Кол-во игр',
    'zh': '游戏场次'
  },
  'sort_winrate': {
    'tr': 'Kazanma Oranı',
    'en': 'Win Rate',
    'ru': 'Процент побед',
    'zh': '胜率'
  },
  'rematch_requested': {
    'tr': 'Rakip tekrar oynamak istiyor!',
    'en': 'Opponent wants a rematch!',
    'ru': 'Соперник хочет реванш!',
    'zh': '对手想要再来一局！'
  },
  'empty_table': {
    'tr': 'Boş Masa',
    'en': 'Empty Table',
    'ru': 'Свободный стол',
    'zh': '空桌位'
  },
  'sit_and_wait': {
    'tr': 'Otur ve Rakip Bekle',
    'en': 'Sit & Wait for Opponent',
    'ru': 'Сесть и ждать соперника',
    'zh': '入座等待对手'
  },
};

String t(String key) {
  final lang = switch (AppSettings.instance.language) {
    AppLanguage.tr => 'tr',
    AppLanguage.en => 'en',
    AppLanguage.ru => 'ru',
    AppLanguage.zh => 'zh',
  };
  // Seçili dilde çeviri yoksa İngilizce'ye, o da yoksa anahtarın kendisine düşer.
  return _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
}
