import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../settings/app_settings.dart';
import '../settings/strings.dart';
import '../settings/telemetry.dart';
import '../settings/user_profile.dart';

class _FeedbackData {
  final String type;
  final String message;
  final String contact;
  const _FeedbackData(this.type, this.message, this.contact);
}

/// Öneri / şikayet / hata bildirimi gönderir. Mesajlar Firestore'daki
/// `feedback` koleksiyonuna yazılır; yalnızca sen Firebase Console'dan okursun.
Future<void> showFeedbackDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final data = await showDialog<_FeedbackData>(
    context: context,
    builder: (_) => const _FeedbackDialog(),
  );
  if (data == null) return;
  var resultKey = 'feedback_thanks';
  try {
    await FirebaseFirestore.instance.collection('feedback').add({
      'type': data.type,
      'message': data.message,
      'contact': data.contact,
      'deviceId': UserProfile.instance.deviceId,
      'lang': AppSettings.instance.language.name,
      'appVersion': Telemetry.appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });
    Telemetry.log('feedback_sent', {'type': data.type});
  } catch (_) {
    resultKey = 'feedback_error';
  }
  messenger.showSnackBar(SnackBar(content: Text(t(resultKey))));
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _message = TextEditingController();
  final _contact = TextEditingController();
  String _type = 'suggestion';

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Widget _chip(String type, String labelKey) => ChoiceChip(
        label: Text(t(labelKey)),
        selected: _type == type,
        onSelected: (_) => setState(() => _type = type),
      );

  @override
  Widget build(BuildContext context) {
    final canSend = _message.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(t('contact_us')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                _chip('suggestion', 'feedback_type_suggestion'),
                _chip('complaint', 'feedback_type_complaint'),
                _chip('bug', 'feedback_type_bug'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: t('feedback_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contact,
              maxLength: 100,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: t('feedback_contact_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel_request')),
        ),
        ElevatedButton(
          onPressed: canSend
              ? () => Navigator.pop(
                  context,
                  _FeedbackData(
                      _type, _message.text.trim(), _contact.text.trim()))
              : null,
          child: Text(t('feedback_send')),
        ),
      ],
    );
  }
}
