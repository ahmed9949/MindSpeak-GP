
// Vertical avatar list widget
import 'package:flutter/material.dart';
import 'package:mind_speak_app/models/avatar.dart';

class VerticalAvatarList extends StatelessWidget {
  final List<AvatarModel> avatars;
  final AvatarModel? selectedAvatar;
  final Function(AvatarModel) onSelectAvatar;
  final bool isDark;

  const VerticalAvatarList({
    Key? key,
    required this.avatars,
    required this.selectedAvatar,
    required this.onSelectAvatar,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isSelected = selectedAvatar?.name == avatar.name;
        
        return AvatarCard(
          avatar: avatar,
          isSelected: isSelected,
          onTap: () => onSelectAvatar(avatar),
          isDark: isDark,
        );
      },
    );
  }
}

// Avatar card widget
class AvatarCard extends StatelessWidget {
  final AvatarModel avatar;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const AvatarCard({
    Key? key,
    required this.avatar,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.1))
              : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Avatar image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey,
                  width: 2,
                ),
                image: DecorationImage(
                  image: AssetImage(avatar.imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Avatar details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avatar.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Voice: ${avatar.voiceId}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.blue,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
