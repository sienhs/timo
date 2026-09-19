import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/timo_logo.dart';
import '../constants.dart';

/// 로고와 검색 입구. 스크롤을 따라 올라가도록 AppBar 가 아니라 본문 위젯이다
/// (시안에서 검색 바가 배너와 함께 스크롤된다).
///
/// 여기서는 입력을 받지 않는다. 누르면 검색 화면으로 넘어가고 입력·결과는
/// 그쪽이 맡는다. 홈에 입력 상태를 두면 홈이 검색 결과까지 알아야 한다.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.onSearchPressed});

  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: HomeMetrics.topBarHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HomeMetrics.horizontalPadding,
        ),
        child: Row(
          children: [
            // 로그인 헤더와 같은 로고·같은 높이. 글자 로고는 이미지가 없을 때의
            // 대체일 뿐이라 여기서 따로 그리지 않는다.
            const TimoLogo(height: HomeMetrics.logoHeight),
            const SizedBox(width: HomeMetrics.logoGap),
            Expanded(
              child: Semantics(
                button: true,
                label: HomeStrings.searchEntry,
                child: InkWell(
                  onTap: onSearchPressed,
                  borderRadius: BorderRadius.circular(
                    HomeMetrics.searchFieldRadius,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: HomeMetrics.searchFieldHeight,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(
                        HomeMetrics.searchFieldRadius,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            HomeStrings.searchHint,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
