import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 더보기로 들어가는 목록 화면들의 상단 바. 뒤로가기와 가운데 제목뿐이다.
/// 검색 화면의 `SearchTopBar` 는 로고를 달고, 이쪽은 어느 섹션에서 왔는지 제목으로 알린다.
class ShowListAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShowListAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: AppColors.textPrimary,
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
