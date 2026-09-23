import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/timo_logo.dart';
import '../constants.dart';

/// 검색 화면 상단 바. 뒤로가기와 로고만 있다. 홈 상단 바(`HomeTopBar`)와 같은
/// 높이·같은 로고이고, 검색 필드는 이 바 아래 한 줄을 통째로 쓴다.
class SearchTopBar extends StatelessWidget {
  const SearchTopBar({super.key, required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeMetrics.topBarHeight,
      child: Row(
        children: [
          IconButton(
            onPressed: onBackPressed,
            tooltip: HomeStrings.back,
            color: AppColors.textPrimary,
            icon: const Icon(Icons.arrow_back),
          ),
          const TimoLogo(height: HomeMetrics.logoHeight),
        ],
      ),
    );
  }
}
