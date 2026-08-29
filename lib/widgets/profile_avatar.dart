import 'dart:io';
import 'package:flutter/material.dart';
import '../settings/user_profile.dart';

/// Profilin fotoğrafı varsa onu, yoksa seçili ikon+renk kombinasyonunu
/// gösteren küçük dairesel avatar. Hem profil ekranında (büyük) hem
/// ana menüde ve oyun ekranlarında (küçük) kullanılıyor.
class ProfileAvatar extends StatelessWidget {
  final double radius;

  const ProfileAvatar({super.key, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserProfile.instance,
      builder: (context, _) {
        final profile = UserProfile.instance;
        if (profile.photoPath != null) {
          final file = File(profile.photoPath!);
          if (file.existsSync()) {
            return CircleAvatar(
              radius: radius,
              backgroundImage: FileImage(file),
            );
          }
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: profile.avatarColor,
          child: Icon(
            kAvatarIcons[profile.avatarIconIndex],
            color: Colors.white,
            size: radius * 1.1,
          ),
        );
      },
    );
  }
}
