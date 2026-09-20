/// 화면 공통 치수. 팬 앱 `core/theme/app_metrics.dart` 와 역할이 같다.
///
/// 모서리 반경·버튼 높이 같은 값을 화면마다 다시 적으면 한 화면만 조금씩
/// 어긋난 채로 남는다. 같은 값은 여기서만 정한다.
///
/// 가로 여백만 팬 앱(16)보다 넓은 20 이다. 게이트 운영자는 한 손으로 폰을
/// 들고 서서 보기 때문에 화면 가장자리에 붙은 글자가 손가락에 가린다.
abstract final class AppMetrics {
  static const pagePadding = 20.0;
  static const cardPadding = 16.0;

  /// 카드·다이얼로그·결과 화면 패널.
  static const cardRadius = 12.0;

  /// 버튼·입력칸. 카드와 같은 값이지만 이름을 나눠 둔다 — 시안에서 둘이
  /// 갈릴 때 호출부를 고치지 않고 이 파일만 고치면 된다.
  static const controlRadius = 12.0;

  static const buttonMinHeight = 52.0;

  /// 앱바 액션처럼 좁은 자리의 버튼. 터치 영역 최소선(44)이다.
  static const compactButtonMinHeight = 44.0;

  static const inlineGap = 8.0;
  static const sectionGap = 24.0;
}
