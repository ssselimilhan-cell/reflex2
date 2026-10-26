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
  'theme_ottoman': {
    'tr': 'Osmanlı Yeniçeri',
    'en': 'Ottoman Janissary',
    'ru': 'Османский янычар',
    'zh': '奥斯曼禁卫军'
  },
  'theme_egypt': {
    'tr': 'Mısır Firavun',
    'en': 'Egyptian Pharaoh',
    'ru': 'Египетский фараон',
    'zh': '埃及法老'
  },
  'theme_rome': {
    'tr': 'Roma İmparatorluğu',
    'en': 'Roman Empire',
    'ru': 'Римская империя',
    'zh': '罗马帝国'
  },
  'theme_animals': {
    'tr': 'Hayvan Figürleri',
    'en': 'Animal Figures',
    'ru': 'Фигуры животных',
    'zh': '动物造型'
  },
  'theme_chinese_zodiac': {
    'tr': 'Çin Burçları',
    'en': 'Chinese Zodiac',
    'ru': 'Китайский зодиак',
    'zh': '中国生肖'
  },
  'theme_matryoshka': {
    'tr': 'Rus Matruşka',
    'en': 'Russian Matryoshka',
    'ru': 'Русская матрёшка',
    'zh': '俄罗斯套娃'
  },
  'theme_soviet': {
    'tr': 'Sovyet / Kremlin',
    'en': 'Soviet / Kremlin',
    'ru': 'Советский / Кремль',
    'zh': '苏联/克里姆林宫'
  },
  'choose_theme': {
    'tr': 'Tema Seç',
    'en': 'Choose Theme',
    'ru': 'Выбрать тему',
    'zh': '选择主题'
  },
  'assisted_mode': {
    'tr': 'Yardımlı Mod (Eşleşmeleri Vurgula)',
    'en': 'Assisted Mode (Highlight Matches)',
    'ru': 'Режим подсказок (подсветка совпадений)',
    'zh': '辅助模式（高亮匹配项）'
  },
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
  'send_invite': {
    'tr': 'Davet Gönder',
    'en': 'Send Invite',
    'ru': 'Отправить приглашение',
    'zh': '发送邀请'
  },
  'invite_received': {
    'tr': 'Sana oyun daveti geldi!',
    'en': 'You received a game invite!',
    'ru': 'Тебе пришло приглашение на игру!',
    'zh': '你收到了游戏邀请！'
  },
  'close_invite': {'tr': 'Kapat', 'en': 'Close', 'ru': 'Закрыть', 'zh': '关闭'},
  'empty_seat': {'tr': 'Boş', 'en': 'Empty', 'ru': 'Пусто', 'zh': '空'},
  'rules_title': {
    'tr': 'Oyun Kuralları',
    'en': 'Game Rules',
    'ru': 'Правила игры',
    'zh': '游戏规则'
  },
  'rules_text': {
    'tr': 'Stres, hız ve refleks gerektiren bir kart oyunudur. Her '
        'oyuncuya 26 kağıt dağıtılır: 22\'si kapalı destede kalır, 4\'ü '
        'oyun alanına açılır — toplam 8 sütun oluşur.\n\nÜst kartı aynı '
        'değere sahip en az 2 sütun varsa, bu sütunlar aktif olur ve '
        'dokunulabilir hâle gelir. Bir sütuna dokunduğunda, kapalı '
        'destenden rastgele bir kart çekilip o sütunun üzerine açık '
        'olarak kapatılır.\n\nEşleşme kalmayınca sütunlar toplanıp '
        'yeniden dağıtılır. Kapalı destesini ilk tamamen bitiren oyuncu '
        'kazanır!',
    'en': 'Stres is a fast-paced reflex card game. Each player is dealt '
        '26 cards: 22 stay in a closed stock pile, 4 are dealt face-up '
        'onto the table — forming 8 columns total.\n\nWhenever at least '
        '2 columns share the same top card value, those columns become '
        'active and tappable. Tapping an active column draws a random '
        'card from your stock and covers it.\n\nWhen no matches remain, '
        'the columns are collected and redealt. The first player to '
        'empty their stock pile wins!',
    'ru': '«Стрес» — карточная игра на скорость и реакцию. Каждому '
        'игроку раздаётся 26 карт: 22 остаются в закрытой колоде, 4 '
        'выкладываются лицом вверх на стол — получается 8 столбцов.\n\n'
        'Как только у двух и более столбцов совпадают значения верхних '
        'карт, эти столбцы становятся активными и доступны для нажатия. '
        'При нажатии на активный столбец из вашей колоды вытягивается '
        'случайная карта и кладётся сверху.\n\nКогда совпадений не '
        'остаётся, столбцы собираются и раздаются заново. Побеждает '
        'тот, кто первым избавится от всей своей колоды!',
    'zh': '《压力》是一款考验反应速度的纸牌游戏。每位玩家发到26张牌：'
        '22张作为暗牌堆，4张翻开放在桌上——总共组成8列。\n\n'
        '当至少有两列的最上面一张牌数值相同时，这些列就会被激活，'
        '可以点击。点击激活的列时，会从你的暗牌堆随机抽一张牌盖在上面。'
        '\n\n当没有任何匹配时，所有列会被收起重新发牌。'
        '最先清空暗牌堆的玩家获胜！',
  },
  'watch_demo': {
    'tr': 'Kısa Demo',
    'en': 'Quick Demo',
    'ru': 'Короткая демонстрация',
    'zh': '简短演示'
  },
  'settings_sound': {
    'tr': 'Ses Efektleri',
    'en': 'Sound Effects',
    'ru': 'Звуковые эффекты',
    'zh': '音效'
  },
  'report_user': {
    'tr': 'Rakibi Bildir',
    'en': 'Report Opponent',
    'ru': 'Пожаловаться на соперника',
    'zh': '举报对手'
  },
  'report_reason_chat': {
    'tr': 'Uygunsuz mesaj',
    'en': 'Inappropriate message',
    'ru': 'Неприемлемое сообщение',
    'zh': '不当消息'
  },
  'report_reason_profile': {
    'tr': 'Uygunsuz isim veya fotoğraf',
    'en': 'Inappropriate name or photo',
    'ru': 'Неприемлемое имя или фото',
    'zh': '不当昵称或头像'
  },
  'report_reason_abuse': {
    'tr': 'Taciz veya hakaret',
    'en': 'Harassment or abuse',
    'ru': 'Оскорбления или домогательства',
    'zh': '骚扰或辱骂'
  },
  'report_reason_other': {'tr': 'Diğer', 'en': 'Other', 'ru': 'Другое', 'zh': '其他'},
  'report_sent': {
    'tr': 'Bildirimin alındı, teşekkürler.',
    'en': 'Report received, thank you.',
    'ru': 'Жалоба получена, спасибо.',
    'zh': '已收到举报，谢谢。'
  },
  'leaderboard_error': {
    'tr': 'Liderlik tablosu yüklenemedi. İnternet bağlantını kontrol et; sorun sürerse Firestore kuralında game_results koleksiyonunun açık olduğundan emin ol.',
    'en': 'Could not load the leaderboard. Check your connection; if it persists, make sure the game_results collection is allowed in your Firestore rules.',
    'ru': 'Не удалось загрузить таблицу лидеров. Проверьте соединение; если ошибка повторяется, проверьте правила Firestore для game_results.',
    'zh': '无法加载排行榜。请检查网络；若仍失败，请确认 Firestore 规则允许 game_results 集合。'
  },
  'terms_title': {
    'tr': 'Kullanım Koşulları',
    'en': 'Terms of Use',
    'ru': 'Условия использования',
    'zh': '使用条款'
  },
  'terms_body': {
    'tr': 'Online özellikleri (lobi, sohbet, davet, liderlik tablosu, profil) kullanarak şunları kabul edersin:\n\n• Hakaret, taciz, nefret söylemi, müstehcen veya yasa dışı içerik (mesaj, isim, fotoğraf) yasaktır.\n• Başkalarının kişisel bilgilerini paylaşmazsın.\n• Uygunsuz içeriği veya davranışı oyun içinden "Rakibi Bildir" ile bildirebilir, oyuncuları "Engelle" ile engelleyebilirsin.\n• Bildirimler incelenir; kuralları ihlal eden içerikler kaldırılabilir ve oyuncuların erişimi sınırlanabilir.\n• Verilerin Gizlilik Politikası\'na göre işlenir.',
    'en': 'By using the online features (lobby, chat, invites, leaderboard, profile) you agree that:\n\n• Insults, harassment, hate speech, sexual or illegal content (messages, names, photos) is not allowed.\n• You will not share other people\'s personal information.\n• You can report inappropriate content or behavior in-game with "Report Opponent" and block players with "Block".\n• Reports are reviewed; content that breaks the rules may be removed and players may lose access.\n• Your data is processed according to the Privacy Policy.',
    'ru': 'Используя онлайн-функции (лобби, чат, приглашения, таблицу лидеров, профиль), вы соглашаетесь:\n\n• Оскорбления, домогательства, разжигание ненависти, сексуальный или незаконный контент (сообщения, имена, фото) запрещены.\n• Не публиковать чужие личные данные.\n• О неприемлемом контенте или поведении можно сообщить в игре через «Пожаловаться на соперника», а игроков — заблокировать.\n• Жалобы рассматриваются; нарушающий правила контент может быть удалён, а доступ игроков ограничен.\n• Ваши данные обрабатываются согласно Политике конфиденциальности.',
    'zh': '使用在线功能（大厅、聊天、邀请、排行榜、个人资料）即表示你同意：\n\n• 禁止辱骂、骚扰、仇恨言论、色情或违法内容（消息、昵称、头像）。\n• 不得分享他人的个人信息。\n• 你可以在游戏内通过“举报对手”举报不当内容或行为，并可屏蔽玩家。\n• 举报会被审核；违规内容可能被删除，相关玩家可能被限制使用。\n• 你的数据将按照隐私政策处理。'
  },
  'block_user': {
    'tr': 'Rakibi Engelle',
    'en': 'Block Opponent',
    'ru': 'Заблокировать соперника',
    'zh': '屏蔽对手'
  },
  'block_short': {'tr': 'Engelle', 'en': 'Block', 'ru': 'Заблокировать', 'zh': '屏蔽'},
  'block_confirm': {
    'tr': 'Bu oyuncu engellensin mi? Odadan çıkarsın; bir daha lobide masaları ve davetleri sana görünmez.',
    'en': 'Block this player? You will leave the room, and their tables and invites will no longer be shown to you.',
    'ru': 'Заблокировать этого игрока? Вы покинете комнату, его столы и приглашения больше не будут отображаться.',
    'zh': '确定屏蔽该玩家吗？你将离开房间，之后将不再看到其牌桌和邀请。'
  },
  'user_blocked': {
    'tr': 'Oyuncu engellendi.',
    'en': 'Player blocked.',
    'ru': 'Игрок заблокирован.',
    'zh': '已屏蔽该玩家。'
  },
  'blocked_players': {
    'tr': 'Engellenen Oyuncular',
    'en': 'Blocked Players',
    'ru': 'Заблокированные игроки',
    'zh': '已屏蔽的玩家'
  },
  'blocked_empty': {
    'tr': 'Engellediğin oyuncu yok.',
    'en': 'You have not blocked anyone.',
    'ru': 'Вы никого не блокировали.',
    'zh': '你没有屏蔽任何玩家。'
  },
  'unblock': {
    'tr': 'Engeli Kaldır',
    'en': 'Unblock',
    'ru': 'Разблокировать',
    'zh': '解除屏蔽'
  },
  'chat_title': {
    'tr': 'Sohbet',
    'en': 'Chat',
    'ru': 'Чат',
    'zh': '聊天'
  },
  'chat_clear': {
    'tr': 'Sohbeti sil',
    'en': 'Clear chat',
    'ru': 'Очистить чат',
    'zh': '清空聊天'
  },
  'chat_clear_confirm': {
    'tr': 'Bu sohbetteki mesajlar yalnızca senin ekranından silinir. Sohbete normal şekilde devam edebilirsin.',
    'en': 'Messages will be removed from your screen only. You can keep chatting as usual.',
    'ru': 'Сообщения будут удалены только на вашем экране. Вы можете продолжать общение.',
    'zh': '消息仅会从你的屏幕上删除，你可以继续正常聊天。'
  },
  'chat_empty': {
    'tr': 'Henüz mesaj yok',
    'en': 'No messages yet',
    'ru': 'Сообщений пока нет',
    'zh': '暂无消息'
  },
  'friend_add': {
    'tr': 'Arkadaş Ekle',
    'en': 'Add Friend',
    'ru': 'Добавить в друзья',
    'zh': '添加好友'
  },
  'friend_remove': {
    'tr': 'Arkadaşlıktan Çıkar',
    'en': 'Remove Friend',
    'ru': 'Удалить из друзей',
    'zh': '删除好友'
  },
  'friend_request_sent': {
    'tr': 'Arkadaşlık isteği gönderildi.',
    'en': 'Friend request sent.',
    'ru': 'Запрос в друзья отправлен.',
    'zh': '好友请求已发送。'
  },
  'friend_already': {
    'tr': 'Zaten arkadaşsınız.',
    'en': 'You are already friends.',
    'ru': 'Вы уже друзья.',
    'zh': '你们已经是好友。'
  },
  'friend_added': {
    'tr': 'Arkadaş eklendi!',
    'en': 'Friend added!',
    'ru': 'Друг добавлен!',
    'zh': '已添加好友！'
  },
  'friend_error': {
    'tr': 'Arkadaşlık isteği gönderilemedi. İnternet bağlantını kontrol et.',
    'en': 'Could not send the friend request. Check your connection.',
    'ru': 'Не удалось отправить запрос. Проверьте соединение.',
    'zh': '无法发送好友请求，请检查网络。'
  },
  'friend_need_profile': {
    'tr': 'Arkadaş eklemek için önce bir profil oluşturmalısın.',
    'en': 'Create a profile first to add friends.',
    'ru': 'Сначала создайте профиль, чтобы добавлять друзей.',
    'zh': '请先创建个人资料再添加好友。'
  },
  'friend_guest': {
    'tr': 'Bu oyuncunun profili yok, arkadaş olarak eklenemez.',
    'en': 'This player has no profile and cannot be added as a friend.',
    'ru': 'У этого игрока нет профиля, его нельзя добавить в друзья.',
    'zh': '该玩家没有个人资料，无法添加为好友。'
  },
  'friend_request_text': {
    'tr': 'seni arkadaş olarak eklemek istiyor',
    'en': 'wants to add you as a friend',
    'ru': 'хочет добавить вас в друзья',
    'zh': '想添加你为好友'
  },
  'friends_filter': {
    'tr': 'Sadece arkadaşlar',
    'en': 'Friends only',
    'ru': 'Только друзья',
    'zh': '仅好友'
  },
  'no_friends_yet': {
    'tr': 'Henüz arkadaşın yok.',
    'en': 'No friends yet.',
    'ru': 'Друзей пока нет.',
    'zh': '还没有好友。'
  },
  'menu_quick_match': {
    'tr': 'Hızlı Eşleş',
    'en': 'Quick Match',
    'ru': 'Быстрая игра',
    'zh': '快速匹配'
  },
  'qm_searching': {
    'tr': 'Rakip aranıyor…',
    'en': 'Finding an opponent…',
    'ru': 'Поиск соперника…',
    'zh': '正在寻找对手…'
  },
  'qm_hint': {
    'tr': 'Rakip bulunamazsa {n} saniye sonra bota karşı başlarsın.',
    'en': 'If no opponent is found, you will play a bot in {n} s.',
    'ru': 'Если соперник не найден, через {n} с начнётся игра с ботом.',
    'zh': '若未找到对手，{n} 秒后将与机器人对战。'
  },
  'qm_play_bot_now': {
    'tr': 'Şimdi bota karşı oyna',
    'en': 'Play the bot now',
    'ru': 'Играть с ботом сейчас',
    'zh': '立即对战机器人'
  },
  'daily_title': {
    'tr': 'Günlük Görevler',
    'en': 'Daily Missions',
    'ru': 'Ежедневные задания',
    'zh': '每日任务'
  },
  'mission_play3': {
    'tr': '3 oyun oyna',
    'en': 'Play 3 games',
    'ru': 'Сыграйте 3 игры',
    'zh': '玩3局游戏'
  },
  'mission_win1': {
    'tr': 'Bir oyun kazan',
    'en': 'Win a game',
    'ru': 'Выиграйте игру',
    'zh': '赢一局'
  },
  'mission_bonus1': {
    'tr': 'Bir seri avantajı kazan',
    'en': 'Earn a streak bonus',
    'ru': 'Получите бонус за серию',
    'zh': '获得一次连击奖励'
  },
  'mission_done': {
    'tr': 'Görev tamamlandı',
    'en': 'Mission complete',
    'ru': 'Задание выполнено',
    'zh': '任务完成'
  },
  'streak_hint': {
    'tr': 'Her gün en az bir oyun oynayarak serini sürdür.',
    'en': 'Keep your streak by playing at least one game every day.',
    'ru': 'Играйте хотя бы одну игру в день, чтобы сохранить серию.',
    'zh': '每天至少玩一局以保持连续天数。'
  },
  'settings_haptics': {
    'tr': 'Titreşim',
    'en': 'Vibration',
    'ru': 'Вибрация',
    'zh': '振动'
  },
  'ob_skip': {
    'tr': 'Atla',
    'en': 'Skip',
    'ru': 'Пропустить',
    'zh': '跳过'
  },
  'ob_next': {
    'tr': 'İleri',
    'en': 'Next',
    'ru': 'Далее',
    'zh': '下一步'
  },
  'ob_play_first': {
    'tr': 'İlk oyunumu oynat',
    'en': 'Play my first game',
    'ru': 'Сыграть первую игру',
    'zh': '开始第一局'
  },
  'ob_to_menu': {
    'tr': 'Menüye git',
    'en': 'Go to menu',
    'ru': 'В меню',
    'zh': '进入菜单'
  },
  'show_tutorial': {
    'tr': 'Eğitimi tekrar göster',
    'en': 'Replay tutorial',
    'ru': 'Повторить обучение',
    'zh': '重新观看教程'
  },
  'ob1_title': {
    'tr': 'Aynı değerleri yakala',
    'en': 'Spot the matches',
    'ru': 'Находи совпадения',
    'zh': '找出相同的牌'
  },
  'ob1_body': {
    'tr': 'Masadaki 8 kolonun üst kartlarına bak. Aynı değere sahip kartlar parlar. Parlayan bir kolona dokun!',
    'en': 'Watch the top cards of the 8 columns. Cards with the same value light up. Tap a glowing column!',
    'ru': 'Смотрите на верхние карты 8 столбцов. Карты с одинаковым значением подсвечиваются. Нажмите на подсвеченный столбец!',
    'zh': '观察8列牌最上面的牌。数值相同的牌会发光。点击发光的牌列！'
  },
  'ob2_title': {
    'tr': 'Desteni ilk bitiren kazanır',
    'en': 'Empty your deck first',
    'ru': 'Первым избавьтесь от колоды',
    'zh': '最先出完牌堆者获胜'
  },
  'ob2_body': {
    'tr': 'Parlayan kolona dokununca destenden bir kart atılır ve eşleşmeyi kapatır. Rakipten önce desteni bitir!',
    'en': 'Tapping a glowing column plays a card from your deck and covers the match. Finish your deck before your opponent!',
    'ru': 'Нажатие на подсвеченный столбец кладёт карту из вашей колоды и закрывает совпадение. Опередите соперника!',
    'zh': '点击发光的牌列会打出一张牌并盖住配对。比对手更快出完牌堆！'
  },
  'ob3_title': {
    'tr': 'Seri yap, bonus kazan',
    'en': 'Build a streak, win bonuses',
    'ru': 'Серия — бонусы',
    'zh': '连击赢奖励'
  },
  'ob3_body': {
    'tr': 'Rakip hamle yapamadan art arda hamle yaparsan destenden kartlar kendiliğinden düşer:',
    'en': 'Make moves in a row before your opponent moves and your deck shrinks on its own:',
    'ru': 'Делайте ходы подряд, пока соперник не ходит, и ваша колода сама уменьшится:',
    'zh': '在对手出牌之前连续出牌，你的牌堆会自动减少：'
  },
  'ob4_title': {
    'tr': 'Hazırsın!',
    'en': 'You\'re ready!',
    'ru': 'Вы готовы!',
    'zh': '准备好了！'
  },
  'ob4_body': {
    'tr': 'Kolay bir botla ilk oyununu hemen oynayabilirsin. Bu eğitimi istediğin zaman Oyun Kuralları ekranından tekrar izleyebilirsin.',
    'en': 'Play your first game right now against an easy bot. You can replay this tutorial anytime from the Rules screen.',
    'ru': 'Сыграйте первую игру прямо сейчас против лёгкого бота. Обучение можно повторить в разделе «Правила».',
    'zh': '现在就和简单难度的机器人玩第一局吧。你可以随时在“游戏规则”中重新观看本教程。'
  },
  'share_room_text': {
    'tr': 'STRES oynayalım! Oda kodu: {code}\nUygulamayı aç → Online → Kod ile katıl.\n{url}',
    'en': 'Let\'s play STRES! Room code: {code}\nOpen the app → Online → Join with code.\n{url}',
    'ru': 'Давай сыграем в STRES! Код комнаты: {code}\nОткрой приложение → Онлайн → Войти по коду.\n{url}',
    'zh': '一起玩 STRES 吧！房间码：{code}\n打开应用 → 在线 → 输入房间码加入。\n{url}'
  },
  'share_app_text': {
    'tr': 'STRES: hızlı refleks kart oyunu. Gel oynayalım! {url}',
    'en': 'STRES: a fast reflex card game. Come play! {url}',
    'ru': 'STRES — быстрая карточная игра на реакцию. Давай играть! {url}',
    'zh': 'STRES：快节奏反应纸牌游戏。来一起玩吧！{url}'
  },
  'share_code_button': {
    'tr': 'Kodu arkadaşına gönder',
    'en': 'Send the code to a friend',
    'ru': 'Отправить код другу',
    'zh': '把房间码发给好友'
  },
  'rate_app': {
    'tr': 'Uygulamayı Değerlendir',
    'en': 'Rate the App',
    'ru': 'Оценить приложение',
    'zh': '为应用评分'
  },
  'feedback_title': {
    'tr': 'Geri Bildirim Gönder',
    'en': 'Send Feedback',
    'ru': 'Отправить отзыв',
    'zh': '发送反馈'
  },
  'feedback_hint': {
    'tr': 'Görüşünü, önerini veya karşılaştığın hatayı yaz (kişisel bilgi yazma).',
    'en': 'Tell us your thoughts, ideas or the bug you hit (no personal info).',
    'ru': 'Напишите мнение, идею или найденную ошибку (без личных данных).',
    'zh': '请写下你的意见、建议或遇到的问题（请勿填写个人信息）。'
  },
  'feedback_type_bug': {'tr': 'Hata', 'en': 'Bug', 'ru': 'Ошибка', 'zh': '问题'},
  'feedback_type_idea': {'tr': 'Öneri', 'en': 'Idea', 'ru': 'Идея', 'zh': '建议'},
  'feedback_type_other': {'tr': 'Diğer', 'en': 'Other', 'ru': 'Другое', 'zh': '其他'},
  'feedback_send': {'tr': 'Gönder', 'en': 'Send', 'ru': 'Отправить', 'zh': '发送'},
  'feedback_cancel': {'tr': 'Vazgeç', 'en': 'Cancel', 'ru': 'Отмена', 'zh': '取消'},
  'feedback_thanks': {
    'tr': 'Geri bildirimin alındı, teşekkürler!',
    'en': 'Feedback received, thank you!',
    'ru': 'Отзыв получен, спасибо!',
    'zh': '已收到你的反馈，谢谢！'
  },
  'feedback_failed': {
    'tr': 'Gönderilemedi. İnternet bağlantını kontrol edip tekrar dene.',
    'en': 'Could not send. Check your connection and try again.',
    'ru': 'Не удалось отправить. Проверьте соединение и попробуйте снова.',
    'zh': '发送失败。请检查网络后重试。'
  },
  'invite_friends': {
    'tr': 'Arkadaşını davet et',
    'en': 'Invite a friend',
    'ru': 'Пригласить друга',
    'zh': '邀请好友'
  },
  'rank_bronze': {
    'tr': 'Bronz',
    'en': 'Bronze',
    'ru': 'Бронза',
    'zh': '青铜'
  },
  'rank_silver': {
    'tr': 'Gümüş',
    'en': 'Silver',
    'ru': 'Серебро',
    'zh': '白银'
  },
  'rank_gold': {
    'tr': 'Altın',
    'en': 'Gold',
    'ru': 'Золото',
    'zh': '黄金'
  },
  'rank_diamond': {
    'tr': 'Elmas',
    'en': 'Diamond',
    'ru': 'Алмаз',
    'zh': '钻石'
  },
  'rank_legend': {
    'tr': 'Efsane',
    'en': 'Legend',
    'ru': 'Легенда',
    'zh': '传奇'
  },
  'next_rank_hint': {
    'tr': 'Sonraki rütbe: {name} — {n} galibiyet kaldı',
    'en': 'Next rank: {name} — {n} wins to go',
    'ru': 'Следующий ранг: {name} — осталось побед: {n}',
    'zh': '下一段位：{name} — 还差 {n} 场胜利'
  },
  'settings_telemetry': {
    'tr': 'Anonim kullanım ve hata verisi gönder',
    'en': 'Send anonymous usage and error data',
    'ru': 'Отправлять анонимные данные об использовании и ошибках',
    'zh': '发送匿名使用与错误数据'
  },
  'streak_bonus_label': {
    'tr': 'Kart!',
    'en': 'Card(s)!',
    'ru': 'карт(ы)!',
    'zh': '张牌！'
  },
  'leaderboard_title': {
    'tr': 'Liderlik Tablosu',
    'en': 'Leaderboard',
    'ru': 'Таблица лидеров',
    'zh': '排行榜'
  },
  'menu_leaderboard': {
    'tr': 'Liderlik Tablosu',
    'en': 'Leaderboard',
    'ru': 'Таблица лидеров',
    'zh': '排行榜'
  },
  'period_daily': {'tr': 'Günlük', 'en': 'Daily', 'ru': 'День', 'zh': '每日'},
  'period_weekly': {
    'tr': 'Haftalık',
    'en': 'Weekly',
    'ru': 'Неделя',
    'zh': '每周'
  },
  'period_monthly': {
    'tr': 'Aylık',
    'en': 'Monthly',
    'ru': 'Месяц',
    'zh': '每月'
  },
  'period_yearly': {'tr': 'Yıllık', 'en': 'Yearly', 'ru': 'Год', 'zh': '每年'},
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
