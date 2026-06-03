import 'package:flutter/material.dart';

/// CircleAvatar that shows [photoUrl] when available, falling back to
/// [initials] text if the image fails to load or is absent.
/// Works reliably on mobile and web via Image.network + ClipOval.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final double radius;
  final Color backgroundColor;
  final TextStyle textStyle;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.initials,
    required this.radius,
    required this.backgroundColor,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    final size = radius * 2;

    if (hasPhoto) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Show initials while the photo is loading
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _initialsAvatar(),
          // Fall back to initials if the URL fails to load
          errorBuilder: (_, __, ___) => _initialsAvatar(),
        ),
      );
    }

    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(initials, style: textStyle),
    );
  }
}
