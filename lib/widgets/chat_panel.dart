import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../online/firestore_game_repository.dart';
import '../settings/strings.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Oyun ekranının altında yalnızca İNCE bir çubuk gösterir (son mesaj +
/// okunmamış sayısı) — oyunu ve oyuncu isimlerini kapatmaz. Dokununca
/// kaydırılabilir bir sohbet paneli açılır. Mesajlar odaya özel bir alt
/// koleksiyonda tutulur; oyundan çıkılınca silinir (bkz.
/// OnlineRoomRepository.clearMessages).
class ChatPanel extends StatefulWidget {
  final String roomCode;
  final PlayerSide mySide;
  final OnlineRoomRepository repo;

  const ChatPanel({
    super.key,
    required this.roomCode,
    required this.mySide,
    required this.repo,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  /// "Sohbeti sil" ile yalnızca BU cihazda gizlenen mesajlar.
  final Set<String> _hiddenIds = {};

  /// Panelde görülmüş (okunmuş) mesajlar.
  final Set<String> _seenIds = {};

  Future<void> _openChat() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ChatSheet(
        roomCode: widget.roomCode,
        mySide: widget.mySide,
        repo: widget.repo,
        hiddenIds: _hiddenIds,
        seenIds: _seenIds,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.repo.watchMessages(widget.roomCode),
      builder: (context, snapshot) {
        final visible = (snapshot.data?.docs ?? [])
            .where((d) => !_hiddenIds.contains(d.id))
            .toList();
        final unread = visible
            .where((d) =>
                d.data()['sender'] != widget.mySide.name &&
                !_seenIds.contains(d.id))
            .length;
        final lastText = visible.isEmpty
            ? null
            : (visible.last.data()['text'] as String? ?? '');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Material(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openChat,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (lastText == null || lastText.isEmpty)
                            ? t('chat_title')
                            : lastText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: lastText == null
                                ? Colors.white54
                                : Colors.white,
                            fontSize: 13),
                      ),
                    ),
                    if (unread > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$unread',
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_up,
                        color: Colors.white54, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatSheet extends StatefulWidget {
  final String roomCode;
  final PlayerSide mySide;
  final OnlineRoomRepository repo;
  final Set<String> hiddenIds;
  final Set<String> seenIds;

  const _ChatSheet({
    required this.roomCode,
    required this.mySide,
    required this.repo,
    required this.hiddenIds,
    required this.seenIds,
  });

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  List<_Doc> _lastVisible = [];

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.repo.sendMessage(widget.roomCode, widget.mySide, text);
    _controller.clear();
    _focus.requestFocus();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  /// Mesajları yalnızca bu cihazda gizler; sohbet sonrasında normal devam eder.
  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('chat_clear')),
        content: Text(t('chat_clear_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('cancel_request')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t('chat_clear')),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.hiddenIds.addAll(_lastVisible.map((d) => d.id));
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Panel klavyenin üstünde kalır ve ekranı taşırmaz.
    final available = mq.size.height - mq.viewInsets.bottom - mq.padding.top - 24;
    final wanted = (mq.size.height * 0.5).clamp(240.0, 460.0).toDouble();
    final height = wanted > available ? available : wanted;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                child: Row(
                  children: [
                    Text(t('chat_title'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white70),
                      tooltip: t('chat_clear'),
                      onPressed: _confirmClear,
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.repo.watchMessages(widget.roomCode),
                  builder: (context, snapshot) {
                    final visible = (snapshot.data?.docs ?? [])
                        .where((d) => !widget.hiddenIds.contains(d.id))
                        .toList();
                    _lastVisible = visible;
                    widget.seenIds.addAll(visible.map((d) => d.id));
                    _toBottom();
                    if (visible.isEmpty) {
                      return Center(
                        child: Text(t('chat_empty'),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 13)),
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final data = visible[i].data();
                        final isMine = data['sender'] == widget.mySide.name;
                        final text = data['text'] as String? ?? '';
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                                maxWidth: mq.size.width * 0.72),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isMine ? Colors.white24 : Colors.white10,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(text,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        maxLength: 120,
                        textInputAction: TextInputAction.send,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: t('chat_hint'),
                          hintStyle: const TextStyle(
                              color: Colors.white38, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white10,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
