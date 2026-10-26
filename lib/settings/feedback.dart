import 'package:cloud_firestore/cloud_firestore.dart';
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
Future<bool> submitFeedback(String type, String message) async {
  if (!firebaseAvailable || _sentThisSession >= 3) return false;
  try {
    await FirebaseFirestore.instance.collection('feedback').add({
      'type': type,
      'message': message.length > 500 ? message.substring(0, 500) : message,
      'deviceId': UserProfile.instance.deviceId,
      'lang': AppSettings.instance.language.name,
      'appVersion': Telemetry.appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 8));
    _sentThisSession++;
    Telemetry.log('feedback_sent', {'type': type});
    return true;
  } catch (_) {
    return false;
  }
}

/// Ayarlar'dan açılan "Geri bildirim gönder" penceresi.
Future<void> showFeedbackDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = TextEditingController();
  var type = 'idea';
  var sending = false;
  final sent = await showDialog<bool>(
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
  if (sent == null) return;
  messenger.showSnackBar(SnackBar(
      content: Text(sent ? t('feedback_thanks') : t('feedback_failed'))));
}
