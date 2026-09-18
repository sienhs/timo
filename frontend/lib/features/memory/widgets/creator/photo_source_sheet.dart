import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../theme/timo_colors.dart';

/// "+" 타일에서 고른 사진 출처.
enum PhotoSource { gallery, camera }

/// 갤러리·카메라 중 하나를 고르는 바텀시트. 닫으면 null.
///
/// 격자는 데모 사진 3장 + "+" 1장으로 2열이 꼭 맞는다. 카메라 타일을 하나 더
/// 놓으면 빈 칸이 생기므로 "+" 안에서 한 겹 골라 들어가게 했다.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<PhotoSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _PhotoSourceSheet(),
  );
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: TimoColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              CreatorText.photoSourceTitle,
              style: textTheme.titleMedium?.copyWith(color: TimoColors.ink),
            ),
          ),
          _SourceTile(
            icon: Icons.photo_library_outlined,
            label: CreatorText.galleryLabel,
            onTap: () => Navigator.pop(context, PhotoSource.gallery),
          ),
          _SourceTile(
            icon: Icons.photo_camera_outlined,
            label: CreatorText.cameraLabel,
            onTap: () => Navigator.pop(context, PhotoSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: TimoColors.brandMid),
    title: Text(
      label,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: TimoColors.ink,
      ),
    ),
    onTap: onTap,
  );
}
