import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 찜 목록 안에서 좁혀 보는 검색 칸. 둥근 회색 상자 + 돋보기.
///
/// 홈의 검색 칸과 모양이 비슷하지만 하는 일이 다르다. 저쪽은 제출했을 때
/// 서버에 묻고, 이쪽은 글자를 칠 때마다 기기에 있는 목록을 거른다 — 화면이
/// [controller] 를 구독하고 있어서 여기서는 따로 알리지 않는다. 글자가 있으면
/// 오른쪽 끝에 지우기가 나타난다.
class FavoriteSearchField extends StatelessWidget {
  const FavoriteSearchField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: FavoriteMetrics.searchFieldHeight,
      padding: const EdgeInsets.only(
        left: FavoriteMetrics.searchFieldHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(FavoriteMetrics.searchFieldRadius),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: FavoriteMetrics.searchFieldIconSize,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: FavoriteMetrics.searchFieldIconGap),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              style: textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // 지우기는 글자가 있을 때만. 컨트롤러를 구독해 이 버튼만 다시 그린다.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(
                    width: FavoriteMetrics.searchFieldHorizontalPadding,
                  )
                : IconButton(
                    onPressed: controller.clear,
                    tooltip: FavoriteStrings.clearSearch,
                    iconSize: FavoriteMetrics.searchFieldIconSize,
                    color: AppColors.textSecondary,
                    icon: const Icon(Icons.cancel),
                  ),
          ),
        ],
      ),
    );
  }
}
