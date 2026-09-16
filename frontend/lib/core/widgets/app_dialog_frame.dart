import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 앱 안 확인 팝업의 공통 틀. 흰 바탕, 둥근 모서리, (있다면) 얇은 색 테두리.
///
/// 아이디 확정 · 좌석 확인 · 예매 취소 팝업이 같은 모양이라 한 곳에 둔다.
/// 각 팝업은 안에 들어갈 내용과 테두리만 정한다. 아이디 확정·좌석 확인은 시안대로
/// 브랜드색 테두리, 예매 취소는 테두리 없이 쓴다(사용자 결정) — [borderColor] 에
/// null 을 주면 안 그린다.
///
/// **테두리를 직접 그리는 이유**: `Dialog` 의 `shape.side` 로는 테두리가
/// 그려지지 않는다(좌석 확인 팝업에서 골든으로 확인). 그래서 `Dialog` 의 배경을
/// 비우고 안쪽 상자에 테두리를 그린다.
///
/// **두께가 1.5 인 이유**: 1.0 으로 두면 420dpi 기기에서 2.625 물리 픽셀이 되는데
/// 정수가 아니라 위치에 따라 3픽셀 또는 2픽셀로 반올림된다. 실제로 위·양옆은
/// 3픽셀, 아래만 2픽셀로 그려져 아래 테두리가 흐리게 보였다. 1.5 는 3.9 픽셀이라
/// 어느 쪽으로 반올림돼도 3 이상이다. 시안의 "얇은 테두리" 느낌은 유지된다.
///
/// 좌우 여백 24 는 좌석 확인 팝업 기준이다. 더 좁히면 '다시 돌아오려고 하면...'
/// 이 두 줄로 갈리며 '요!' 만 다음 줄에 남는다.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.child,
    this.borderColor = AppColors.primary,
    this.padding = defaultPadding,
  });

  static const defaultPadding = EdgeInsets.fromLTRB(20, 24, 20, 20);

  /// 위 주석 참고. 테두리를 그리는 팝업이 같은 값을 써야 하니 여기서만 정한다.
  static const borderWidth = 1.5;

  final Widget child;

  /// 테두리 색. null 이면 테두리를 그리지 않는다.
  final Color? borderColor;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final borderColor = this.borderColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: borderColor == null
              ? null
              : Border.all(color: borderColor, width: borderWidth),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
