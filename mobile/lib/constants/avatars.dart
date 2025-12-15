import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';

/// Spy-themed avatar icons for player selection.
enum SpyAvatar {
  agent('Agent', Icons.person),
  hacker('Hacker', Icons.computer),
  spy('Spy', Icons.visibility),
  detective('Detective', Icons.search),
  ninja('Ninja', Icons.sports_martial_arts),
  phantom('Phantom', Icons.theater_comedy),
  shadow('Shadow', Icons.nights_stay),
  ghost('Ghost', Icons.blur_on),
  cipher('Cipher', Icons.lock),
  wolf('Wolf', Icons.pets);

  const SpyAvatar(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Get avatar by name (case insensitive)
  static SpyAvatar? fromString(String? name) {
    if (name == null) return null;
    try {
      return SpyAvatar.values.firstWhere(
        (avatar) => avatar.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Widget to display an avatar icon in a circle
class AvatarIcon extends StatelessWidget {
  const AvatarIcon({
    super.key,
    required this.avatar,
    this.size = 40,
    this.selected = false,
  });

  final SpyAvatar avatar;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Palette.primary : Palette.primary.withAlpha(51),
        border: Border.all(
          color: selected ? Palette.primaryBright : Palette.stroke,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Palette.primary.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Icon(
        avatar.icon,
        color: selected ? Palette.text : Palette.primaryBright,
        size: size * 0.5,
      ),
    );
  }
}
