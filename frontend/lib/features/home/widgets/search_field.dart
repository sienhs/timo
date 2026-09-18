import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 검색어 입력 칸. 홈 상단 바의 검색 입구와 같은 모양(둥근 회색 상자 + 돋보기)
/// 이되, 여기서는 실제로 글자를 받는다.
///
/// 제출([onSubmitted])했을 때만 검색한다. 글자가 있으면 오른쪽 끝에 지우기가
/// 나타나고, 누르면 비우고 [onCleared] 를 부른다 — 화면은 이걸 받아 검색 전
/// 상태로 돌아간다.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onCleared,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;
  final bool autofocus;

  void _clear() {
    controller.clear();
    onCleared();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: HomeMetrics.searchFieldHeight,
      padding: const EdgeInsets.only(
        left: HomeMetrics.searchFieldHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(HomeMetrics.searchFieldRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: HomeMetrics.searchFieldIconSize,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: HomeMetrics.searchFieldIconGap),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: HomeStrings.searchHint,
                hintStyle: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                // 바깥 상자가 테두리 노릇을 하니 칸 자체의 선은 모두 뗀다.
                // `border` 만 none 으로 두면 테마가 상태별로 정한
                // enabledBorder·focusedBorder 가 그대로 남아 글자 둘레에 가는
                // 선이 그려진다.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
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
                    width: HomeMetrics.searchFieldHorizontalPadding,
                  )
                : IconButton(
                    onPressed: _clear,
                    tooltip: HomeStrings.clearSearch,
                    iconSize: HomeMetrics.searchFieldIconSize,
                    color: AppColors.textSecondary,
                    icon: const Icon(Icons.cancel),
                  ),
          ),
        ],
      ),
    );
  }
}
