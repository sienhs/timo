import '../../core/theme/app_metrics.dart';

/// 환경 설정 화면 치수. 시안이 없어 마이페이지의 여백과 앱 공통 카드 규칙을
/// 빌렸다.
class SettingsMetrics {
  SettingsMetrics._();

  /// 좌우 여백. 마이페이지와 같다 — 하단 바의 마이페이지에서 오갈 때 카드
  /// 왼쪽 끝이 맞는다.
  static const horizontalPadding = 20.0;
  static const verticalPadding = 20.0;

  /// 섹션 사이, 섹션 제목과 카드 사이 간격.
  static const sectionGap = 24.0;
  static const sectionTitleGap = 8.0;

  /// 항목을 묶는 테두리 카드.
  static const cardRadius = AppMetrics.cardRadius;

  /// 항목 한 줄.
  static const tileHorizontalPadding = 16.0;
  static const tileIconSize = 22.0;
  static const chevronSize = 20.0;

  /// 로그인 안 한 상태의 안내 카드 안쪽 여백과 문구·버튼 사이 간격.
  static const guestPadding = 16.0;
  static const guestGap = 12.0;
}

/// 환경 설정 문구.
class SettingsStrings {
  SettingsStrings._();

  /// 빠른 메뉴의 항목 이름과 같다. 눌렀던 이름과 화면 제목이 다르면 다른
  /// 곳에 온 것처럼 읽힌다.
  static const title = '환경 설정';

  // 계정. 셋 다 요구사항 문서에 있는 기능이라 자리를 먼저 잡아 둔다.
  static const accountSection = '계정';
  static const editProfile = '프로필 수정';
  static const changePassword = '비밀번호 변경';
  static const deleteAccount = '회원 탈퇴';

  /// 로그인 안 한 상태에서 계정 섹션 자리에 적는다.
  static const loginPrompt = '로그인하면 계정 설정을 볼 수 있어요.';

  // 알림
  static const notificationSection = '알림';
  static const pushToggle = '푸시 알림 받기';
  static const inbox = '알림함';

  // 앱 정보
  static const infoSection = '앱 정보';
  static const version = '버전';

  /// 라이선스 화면 제목에 쓰는 앱 이름.
  static const appName = 'TIMO';

  /// pubspec 의 version 과 같아야 한다. 패키지 정보를 읽어 오는 의존성이
  /// 아직 없어 글자로 둔다 — 버전을 올릴 때 여기도 같이 고친다.
  static const appVersion = '1.0.0';
  static const terms = '이용약관';
  static const privacy = '개인정보 처리방침';
  static const licenses = '오픈소스 라이선스';

  /// 화면이 아직 없는 항목을 눌렀을 때.
  static String notReady(String label) => '$label 화면은 준비 중이에요.';
}
