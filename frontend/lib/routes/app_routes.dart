import 'package:flutter/material.dart';

import '../features/auth/models/signup_draft.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_code_screen.dart';
import '../features/auth/screens/signup_complete_screen.dart';
import '../features/auth/screens/signup_name_screen.dart';
import '../features/auth/screens/signup_nickname_screen.dart';
import '../features/auth/screens/signup_password_screen.dart';
import '../features/auth/screens/signup_phone_screen.dart';
import '../features/auth/screens/signup_username_screen.dart';
import '../features/booking/screens/seat_selection_screen.dart';
import '../features/booking/screens/zone_selection_screen.dart';
import '../features/booking/state/ticket_order_adapter.dart';
import '../features/shell/screens/main_shell_screen.dart';
import '../features/show/data/mock_show_detail_data.dart';
import '../features/show/screens/show_detail_screen.dart';
import '../features/payment/screens/payment_complete_screen.dart';
import '../features/payment/screens/payment_screen.dart';

/// 화면 라우트 등록부.
/// 새 화면을 만들면 1) 이름 상수 추가, 2) routes 맵에 builder 등록.
/// 이동은 Navigator.pushNamed(context, AppRoutes.xxx) 사용.
class AppRoutes {
  AppRoutes._();

  static const home = '/';

  /// 공연 상세. 공연 id 를 arguments 로 받는다.
  static const showDetail = '/show';

  /// 구역 배치도(좌석 선택 시작)
  static const zoneSelection = '/booking/zones';

  /// 구역 하나의 좌석 배치도. 구역 id 를 arguments 로 받는다.
  static const seatSelection = '/booking/seats';

  static const payment = '/payment';
  static const paymentComplete = '/payment/complete';

  /// 로그인. 성공하면 결과로 true 를 넘기며 이전 화면으로 돌아간다.
  static const login = '/login';

  /// 회원가입. 단계 화면은 앞 단계까지 채운 SignupDraft 를 arguments 로 받는다.
  static const signupPhone = '/signup/phone';
  static const signupCode = '/signup/code';
  static const signupName = '/signup/name';
  static const signupUsername = '/signup/username';
  static const signupPassword = '/signup/password';
  static const signupNickname = '/signup/nickname';
  static const signupComplete = '/signup/complete';

  static final Map<String, WidgetBuilder> routes = {
    // 홈은 하단 바를 두른 셸이다. 탭 본문(홈·마이페이지)은 셸이 들고 있어
    // 라우트로 노출하지 않는다.
    home: (_) => const MainShellScreen(),
    // 목록에서는 공연 id 만 넘어온다. 상세 조회를 여기서 해 두면 화면은
    // 모델만 받아 그리므로 상태별로 단독 실행할 수 있다. 모르는 id 로
    // 열리면(딥링크) 표본 공연으로 대체한다.
    showDetail: (context) => ShowDetailScreen(
          detail: MockShowDetailData.byId(
            ModalRoute.of(context)!.settings.arguments as String?,
          ),
        ),
    zoneSelection: (_) => const ZoneSelectionScreen(),
    // 인자를 받는 화면은 여기서 한 번만 꺼내 타입을 맞춘다. 화면 위젯이
    // ModalRoute 를 직접 뒤지지 않게 해서 단독 테스트가 가능하다.
    seatSelection: (context) => SeatSelectionScreen(
          zoneId: ModalRoute.of(context)!.settings.arguments as String,
        ),
    // 고른 좌석으로 주문을 만들어 넘긴다. 이 연결이 없으면 어떤 좌석을 골라도
    // 결제 화면에 더미 좌석(A구역 9열 6번)이 찍힌다. 예매 흐름을 거치지 않고
    // 열린 경우는 ticketOrderOrSample 이 더미로 대체한다.
    payment: (context) => PaymentScreen(order: ticketOrderOrSample(context)),
    paymentComplete: (context) =>
        PaymentCompleteScreen(order: ticketOrderOrSample(context)),
    login: (_) => const LoginScreen(),
    signupPhone: (_) => const SignupPhoneScreen(),
    signupCode: (context) => SignupCodeScreen(draft: _signupDraft(context)),
    signupName: (context) => SignupNameScreen(draft: _signupDraft(context)),
    signupUsername: (context) =>
        SignupUsernameScreen(draft: _signupDraft(context)),
    signupPassword: (context) =>
        SignupPasswordScreen(draft: _signupDraft(context)),
    signupNickname: (context) =>
        SignupNicknameScreen(draft: _signupDraft(context)),
    signupComplete: (_) => const SignupCompleteScreen(),
  };

  /// 회원가입 단계 화면이 받는 초안. 초안 없이 열리면(화면 단위 테스트,
  /// 딥링크) 빈 초안으로 시작해 화면이 죽지 않게 한다.
  static SignupDraft _signupDraft(BuildContext context) =>
      ModalRoute.of(context)!.settings.arguments as SignupDraft? ??
      const SignupDraft();
}
