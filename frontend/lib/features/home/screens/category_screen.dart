import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/show_category.dart';
import '../widgets/show_list_app_bar.dart';

/// 카테고리. 빠른 메뉴의 '카테고리' 로 들어온다. 서버의 공연 장르 여섯을 격자로
/// 늘어놓고([showCategories]), 공연이 있는 콘서트만 공연 전체 조회로 보내고
/// 나머지는 흐리게 그린 채 준비 중 안내를 띄운다.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  void _open(BuildContext context, ShowCategory category) {
    if (!category.isAvailable) {
      showInfoSnackBar(context, HomeStrings.categoryNotReady(category.label));
      return;
    }
    Navigator.pushNamed(context, AppRoutes.allShows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const ShowListAppBar(title: HomeStrings.categoryTitle),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeMetrics.horizontalPadding,
            vertical: HomeMetrics.categoryVerticalPadding,
          ),
          children: [
            _CategoryGrid(onSelected: (category) => _open(context, category)),
            const SizedBox(height: HomeMetrics.categoryNoteGap),
            Text(
              HomeStrings.categoryNote,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3열 격자. 빠른 메뉴 패널처럼 GridView 대신 Row 를 쌓는다 — 칸이 여섯으로
/// 고정이라, 스스로 높이를 정하지 못하는 GridView 를 쓸 이유가 없다.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.onSelected});

  final ValueChanged<ShowCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    const columns = HomeMetrics.categoryColumns;
    const items = showCategories;

    return Column(
      children: [
        for (var start = 0; start < items.length; start += columns) ...[
          if (start > 0) const SizedBox(height: HomeMetrics.categoryGap),
          Row(
            children: [
              for (var i = start; i < start + columns; i++) ...[
                if (i > start) const SizedBox(width: HomeMetrics.categoryGap),
                // 마지막 줄이 덜 찼을 때 남은 칸을 비워 정렬을 유지한다.
                Expanded(
                  child: i < items.length
                      ? _CategoryCard(
                          items[i],
                          onPressed: () => onSelected(items[i]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// 장르 한 칸. 공연이 없는 장르는 아이콘과 이름을 흐리게 하고 뱃지를 단다.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard(this.category, {required this.onPressed});

  final ShowCategory category;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = category.isAvailable
        ? AppColors.textPrimary
        : AppColors.textDisabled;

    return AspectRatio(
      aspectRatio: HomeMetrics.categoryCardAspectRatio,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeMetrics.categoryCardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category.icon,
                      size: HomeMetrics.categoryIconSize,
                      color: color,
                    ),
                    const SizedBox(height: HomeMetrics.categoryLabelGap),
                    Text(
                      category.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!category.isAvailable)
                const Positioned(
                  top: HomeMetrics.categoryBadgeInset,
                  right: HomeMetrics.categoryBadgeInset,
                  child: _NotReadyBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotReadyBadge extends StatelessWidget {
  const _NotReadyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeMetrics.categoryBadgeHorizontalPadding,
        vertical: HomeMetrics.categoryBadgeVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(HomeMetrics.badgeRadius),
      ),
      child: Text(
        HomeStrings.categoryNotReadyBadge,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
