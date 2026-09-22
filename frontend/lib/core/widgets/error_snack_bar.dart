import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 서버·네트워크 오류 문구를 화면 아래 스낵바로 띄운다.
///
/// 입력칸과 관련 없는 실패(문자 발송 횟수 초과, 인터넷 끊김, 서버 오류)에 쓴다.
/// 입력칸과 관련된 실패는 그 칸 아래 문구로 보여주는 쪽이 맞다.
///
/// 모양은 앱 공통 스낵바(검정 배경, 안내용)와 다르다. 흰 상자를 그림자로 띄우고
/// 글자는 가운데 정렬한다.
///
/// 하단 고정 버튼을 가리지 않도록 그 위에 뜬다. 오류 뒤에 다시 눌러야 할
/// 버튼이 스낵바 뒤에 숨으면 "왜 안 눌리지" 가 된다.
///
/// 이전 스낵바가 아직 떠 있으면 먼저 지운다. 같은 버튼을 두 번 눌러 오류가
/// 두 번 나면 스낵바가 줄지어 기다리는데, 두 번째는 이미 본 문구라 기다릴 이유가
/// 없다. (좌석·구역 선택 화면이 안내 스낵바를 띄우는 방식과 같다.)
void showErrorSnackBar(
  BuildContext context,
  String message, {
  double? bottomMargin,
}) {
  _showFloatingSnackBar(context, message, bottomMargin: bottomMargin);
}

/// 성공 안내도 오류 안내와 같은 위치와 모양으로 보여준다.
///
/// [fitContent] 를 주면 상자가 화면 폭을 다 쓰지 않고 글자만큼만 넓어진다.
/// 짧은 한 줄 안내가 카드 위에 뜰 때 쓴다 — 카드와 같은 폭의 흰 상자는 안내가
/// 아니라 카드가 하나 더 생긴 것처럼 보인다.
void showSuccessSnackBar(
  BuildContext context,
  String message, {
  double? bottomMargin,
  bool fitContent = false,
}) {
  _showFloatingSnackBar(
    context,
    message,
    bottomMargin: bottomMargin,
    fitContent: fitContent,
  );
}

/// 잘되지도 잘못되지도 않은 안내. "아직 준비 중인 화면" 같은 것.
///
/// 검정 배경의 기본 스낵바를 쓰지 않는 이유는, 같은 화면에서 오류 스낵바와
/// 번갈아 뜨면 두 안내의 생김새가 아예 달라 같은 앱으로 보이지 않아서다.
///
/// [bottomMargin] 은 스낵바 아래 여백이다. 하단 바가 있는 화면은 그 높이만큼
/// 띄워야 안내가 바에 가리지 않는다.
void showInfoSnackBar(
  BuildContext context,
  String message, {
  double? bottomMargin,
  bool fitContent = false,
}) {
  _showFloatingSnackBar(
    context,
    message,
    bottomMargin: bottomMargin,
    fitContent: fitContent,
  );
}

void _showFloatingSnackBar(
  BuildContext context,
  String message, {
  double? bottomMargin,
  bool fitContent = false,
}) {
  final textTheme = Theme.of(context).textTheme;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // 모양은 안쪽 상자가 그린다. SnackBar 자체는 투명하게 두어 흰 상자만
        // 보이게 한다.
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        // 자르지 않는다. 기본값(hardEdge)이면 안쪽 상자의 그림자가 상자 밖으로
        // 퍼지는 부분에서 잘려 나가고, 흰 배경 위의 흰 상자는 경계가 아예
        // 사라진다.
        clipBehavior: Clip.none,
        margin: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          bottomMargin ?? _aboveBottomButton,
        ),
        content: Align(
          child: Container(
            width: fitContent ? null : double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              // 흰 배경 위의 흰 상자다. 경계를 그리는 것이 그림자뿐이므로 빼면
              // 안내가 배경에 묻는다.
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              softWrap: true,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
}

/// 하단 고정 버튼 높이(52) + 버튼 아래 여백(16) + 버튼과 스낵바 사이 틈(12).
///
/// 하단 바를 **본문 안에** 그리는 화면(공연 상세)과 본문 아래에 고정 버튼을 둔
/// 화면(결제)이 이만큼을 필요로 한다. 기본값으로 둔다.
const _aboveBottomButton = 80.0;

/// 하단 바를 `Scaffold.bottomNavigationBar` 로 그리는 화면에서 쓸 여백.
///
/// 그런 화면에서는 떠 있는 스낵바를 **Flutter 가 이미 바 위로 올려 준다.**
/// 그래서 바 높이를 더할 필요가 없고, 여기서는 숨 쉴 틈만 준다. 바 높이를
/// 또 더하면 두 번 밀려 스낵바가 화면 한가운데쯤에 뜬다.
const snackBarGapAboveBar = 12.0;
