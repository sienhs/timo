import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 앱 안 확인 팝업의 공통 틀. 흰 바탕, 둥근 모서리.
///
/// 아이디 확정 · 좌석 확인 · 예매 취소 팝업이 같은 모양이라 한 곳에 둔다.
/// 각 팝업은 안에 들어갈 내용만 정한다.
///
/// **바탕을 안쪽 상자가 그리는 이유**: `Dialog` 에 배경과 그림자를 맡기면
/// 기본 그림자가 따라붙는다. 팝업 뒤는 이미 어두워져 있어 그림자가 필요 없고,
/// 있으면 모서리 둘레가 지저분해진다. 그래서 `Dialog` 는 비워 두고 안쪽 상자가
/// 바탕과 모서리를 그린다.
///
/// 좌우 여백 24 는 좌석 확인 팝업 기준이다. 더 좁히면 '다시 돌아오려고 하면...'
/// 이 두 줄로 갈리며 '요!' 만 다음 줄에 남는다.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.child,
    this.padding = defaultPadding,
  });

  static const defaultPadding = EdgeInsets.fromLTRB(20, 24, 20, 20);

  final Widget child;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
