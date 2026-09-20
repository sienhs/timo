import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 더보기로 들어가는 목록 화면들의 상단 바. 뒤로가기와 가운데 제목뿐이다.
///
/// 검색 화면의 [SearchTopBar] 와 나눠 둔다. 저쪽은 로고를 달아 "앱의 한 화면"
/// 임을 알리는 자리고, 이쪽은 어느 섹션에서 들어왔는지를 제목으로 알려야 하는
/// 자리다. 상단 바를 화면마다 적으면 제목 크기와 뒤로가기 색이 조금씩 갈린다.
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
