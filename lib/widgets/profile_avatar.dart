import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../settings/user_profile.dart';

/// Profilin fotoğrafı varsa onu, yoksa seçili ikon+renk kombinasyonunu
/// gösteren küçük dairesel avatar.
///
/// İki kullanım şekli var:
/// - `ProfileAvatar()` — BU cihazın kendi profilini gösterir (canlı,
///   UserProfile değiştikçe otomatik güncellenir).
/// - `ProfileAvatar.remote(...)` — Firestore'dan gelen BAŞKA bir
///   oyuncunun (rakip, lobideki bir oyuncu) verisiyle statik gösterim
///   yapar.
class ProfileAvatar extends StatelessWidget {
  final double radius;
  final bool _isRemote;
  final String? _remotePhotoBase64;
  final int? _remoteIconIndex;
  final Color? _remoteColor;

  const ProfileAvatar({super.key, this.radius = 16})
      : _isRemote = false,
        _remotePhotoBase64 = null,
        _remoteIconIndex = null,
        _remoteColor = null;

  const ProfileAvatar.remote({
    super.key,
    this.radius = 16,
    String? photoBase64,
    int? iconIndex,
    Color? color,
  })  : _isRemote = true,
        _remotePhotoBase64 = photoBase64,
        _remoteIconIndex = iconIndex,
        _remoteColor = color;

  @override
  Widget build(BuildContext context) {
    if (_isRemote) {
      return _buildFromRemoteData(
        _remotePhotoBase64,
        _remoteIconIndex ?? 0,
        _remoteColor ?? const Color(0xFF0B6E4F),
      );
    }
    return AnimatedBuilder(
      animation: UserProfile.instance,
      builder: (context, _) => _buildFromOwnProfile(UserProfile.instance),
    );
  }

  Widget _buildFromOwnProfile(UserProfile profile) {
    if (profile.photoPath != null) {
      final file = File(profile.photoPath!);
      if (file.existsSync()) {
        return CircleAvatar(radius: radius, backgroundImage: FileImage(file));
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
  }

  Widget _buildFromRemoteData(
      String? photoBase64, int iconIndex, Color color) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64);
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
      } catch (_) {
        // Bozuk/eksik veri varsa ikona düş.
      }
    }
    final safeIndex = iconIndex.clamp(0, kAvatarIcons.length - 1);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Icon(kAvatarIcons[safeIndex], color: Colors.white, size: radius * 1.1),
    );
  }
}
