import 'package:flutter/material.dart';
import 'package:imposter_app/constants/avatars.dart';
import 'package:imposter_app/constants/palette.dart';

/// Widget for selecting a spy avatar from available options.
class AvatarSelector extends StatelessWidget {
  const AvatarSelector({
    super.key,
    required this.selectedAvatar,
    required this.onAvatarSelected,
  });

  final SpyAvatar selectedAvatar;
  final ValueChanged<SpyAvatar> onAvatarSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select avatar',
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: SpyAvatar.values.map((avatar) {
            final isSelected = avatar == selectedAvatar;
            return GestureDetector(
              onTap: () => onAvatarSelected(avatar),
              child: Column(
                children: [
                  AvatarIcon(
                    avatar: avatar,
                    size: 48,
                    selected: isSelected,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    avatar.label,
                    style: TextStyle(
                      color: isSelected ? Palette.primaryBright : Palette.muted,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
