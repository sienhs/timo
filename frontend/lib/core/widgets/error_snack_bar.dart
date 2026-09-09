import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 서버·네트워크 오류 문구를 화면 아래 스낵바로 띄운다.
///
/// 입력칸과 관련 없는 실패(문자 발송 횟수 초과, 인터넷 끊김, 서버 오류)에 쓴다.
/// 입력칸과 관련된 실패는 그 칸 아래 문구로 보여주는 쪽이 맞다.
///
/// 모양은 앱 공통 스낵바(검정 배경, 안내용)와 다르다. 오류라는 게 보이도록
/// 흰 상자에 얇은 코랄 테두리를 두르고 글자는 가운데 정렬한다. 입력칸 오류
/// 글자와 같은 색 계열이라 앱 안에서 통일된다. 아이디 확정 팝업(흰 배경 + 얇은
/// 초록 테두리)과 같은 결이다.
///
/// 하단 고정 버튼을 가리지 않도록 그 위에 뜬다. 오류 뒤에 다시 눌러야 할
/// 버튼이 스낵바 뒤에 숨으면 "왜 안 눌리지" 가 된다.
///
/// 이전 스낵바가 아직 떠 있으면 먼저 지운다. 같은 버튼을 두 번 눌러 오류가
/// 두 번 나면 스낵바가 줄지어 기다리는데, 두 번째는 이미 본 문구라 기다릴 이유가
/// 없다. (좌석·구역 선택 화면이 안내 스낵바를 띄우는 방식과 같다.)
void showErrorSnackBar(BuildContext context, String message) {
  final textTheme = Theme.of(context).textTheme;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // 모양은 안쪽 상자가 그린다. SnackBar 자체는 투명하게 두어 흰 상자와
        // 코랄 테두리만 보이게 한다. (SnackBar 의 shape.side 는 그려지지 않는다.)
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, _aboveBottomButton),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent),
            // 흰 배경 위의 흰 상자라 테두리만으로는 떠 있는 느낌이 없어 옅은
            // 그림자를 깐다.
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
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ),
    );
}

/// 하단 고정 버튼 높이(52) + 버튼 아래 여백(16) + 버튼과 스낵바 사이 틈(12).
const _aboveBottomButton = 80.0;
