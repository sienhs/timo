import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 양도마켓 화면들의 상단 바. 뒤로가기 · 가운데 제목 · 오른쪽 자리 하나
/// ([trailing]). 화면마다 적으면 제목 크기와 뒤로가기 색이 조금씩 갈린다.
class ResaleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ResaleAppBar({super.key, required this.title, this.trailing});

  final String title;

  /// 제목 오른쪽에 놓을 것. 없으면 그 자리는 비워 둔다.
  final Widget? trailing;

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
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        if (trailing case final trailing?)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: trailing),
          ),
      ],
    );
  }
}
