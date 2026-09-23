import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 서버·네트워크 오류 문구를 화면 아래 스낵바로 띄운다. 입력칸과 관련 없는
/// 실패에 쓰고, 입력칸 관련 실패는 그 칸 아래 문구로 보여 준다. 하단 고정 버튼을
/// 가리지 않게 그 위에 뜨고, 이전 스낵바가 아직 떠 있으면 먼저 지운다.
void showErrorSnackBar(
  BuildContext context,
  String message, {
  double? bottomMargin,
}) {
  _showFloatingSnackBar(context, message, bottomMargin: bottomMargin);
}

/// 성공 안내도 오류 안내와 같은 위치와 모양으로 보여준다. [fitContent] 를 주면
/// 상자가 화면 폭을 다 쓰지 않고 글자만큼만 넓어진다(카드 위의 짧은 한 줄 안내).
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

/// 잘되지도 잘못되지도 않은 안내. "아직 준비 중인 화면" 같은 것. 오류 스낵바와
/// 생김새를 맞추려고 검정 기본 스낵바를 쓰지 않는다. [bottomMargin] 은 스낵바
/// 아래 여백으로, 하단 바가 있는 화면은 그 높이만큼 띄워야 바에 가리지 않는다.
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
        duration: toastDuration,
        // 모양은 안쪽 상자가 그린다. SnackBar 자체는 투명하게 두어 흰 상자만
        // 보이게 한다.
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        // 자르지 않는다. 기본값(hardEdge)이면 안쪽 상자의 그림자가 잘려 나가
        // 흰 배경 위의 흰 상자는 경계가 아예 사라진다.
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
              toastText(message),
              // 화면 읽기는 줄 바꿈·단어 묶음 기호가 들어가기 전 문구로 한다.
              semanticsLabel: message,
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

/// 토스트가 떠 있는 시간. Flutter 기본값(4초)은 짧은 안내에 비해 길어서 줄였다.
const toastDuration = Duration(seconds: 2);

/// 토스트에 실제로 그리는 문구. 문장마다 줄을 넘기고, 한글이 단어 중간에서 줄
/// 바뀌지 않게 글자 사이에 폭 없는 단어 묶음 기호(U+2060)를 넣는다. 테스트에서
/// 토스트 문구를 찾을 때도 이 함수를 거친 값으로 찾는다.
String toastText(String message) => message
    .replaceAll(_sentenceBoundary, '\n')
    .split('\n')
    .map(
      (line) => line
          .split(' ')
          .map((word) => word.characters.join(_wordJoiner))
          .join(' '),
    )
    .join('\n');

/// 마침표·물음표·느낌표 뒤의 띄어쓰기(또는 이미 넣어 둔 줄 바꿈).
/// 뒤에 글자가 더 있을 때만 — 문구 끝의 공백에서 빈 줄이 생기지 않게.
final _sentenceBoundary = RegExp(r'(?<=[.!?])\s+(?=\S)');

const _wordJoiner = '\u2060';

/// 하단 고정 버튼 높이(52) + 버튼 아래 여백(16) + 버튼과 스낵바 사이 틈(12).
/// 본문 안에 하단 바를 그리거나 본문 아래 고정 버튼을 둔 화면의 기본값이다.
const _aboveBottomButton = 80.0;

/// 하단 바를 `Scaffold.bottomNavigationBar` 로 그리는 화면에서 쓸 여백. 그런
/// 화면에서는 Flutter 가 이미 스낵바를 바 위로 올려 주므로 바 높이를 또 더하면
/// 두 번 밀려 화면 한가운데쯤에 뜬다. 여기서는 숨 쉴 틈만 준다.
const snackBarGapAboveBar = 12.0;
