/// 로딩(스플래시) 화면의 문구·시간·크기 상수.
///
/// 시안 '로딩 1~4' 는 한 애니메이션의 네 장면이다. 장면 순서와 각 장면이 머무는
/// 시간을 한 곳에 두어, 시간을 손볼 때 화면 코드와 테스트가 같은 값을 보게 한다
/// (인증 도메인의 AuthMetrics 와 같은 방식).
class SplashMetrics {
  SplashMetrics._();

  /// 장면이 머무는 시간. 순서대로 로딩 1·2·3·4.
  ///
  /// 첫 장면은 눈이 화면에 닿을 시간을 줘 조금 길고, 마지막 로고는 브랜드가
  /// 남도록 가장 길다. 합쳐서 2.5초. 에뮬레이터에서 보고 조정한다.
  static const stepDurations = [
    Duration(milliseconds: 600),
    Duration(milliseconds: 500),
    Duration(milliseconds: 500),
    Duration(milliseconds: 900),
  ];

  /// 장면이 바뀔 때 앞 장면이 사라지고 다음 장면이 나타나는 크로스페이드 길이.
  ///
  /// 장면이 머무는 시간 **안에** 든다(장면이 바뀌는 순간부터 센다). 그래서
  /// 장면이 온전히 보이는 시간은 머무는 시간에서 이만큼을 뺀 값이다.
  static const fadeDuration = Duration(milliseconds: 200);

  /// 첫 장면이 뜬 순간부터 홈으로 넘어가기까지. 테스트가 이만큼 시간을 돌린다.
  static final totalDuration = stepDurations.fold<Duration>(
    Duration.zero,
    (sum, step) => sum + step,
  );

  // 크기는 시안 이미지의 비율에서 왔다. 시안에서 문구와 워드마크('ticket moa')는
  // 화면 폭의 절반을 조금 넘고(54~57%), 'TIMO' 는 26%, 로고는 41% 다. 에뮬레이터
  // 스크린샷을 픽셀로 재어 그 비율이 나오는 값으로 맞췄다(2026-09-17).

  /// 문구('세상의 모든 티켓을 모아,') 글자 크기. 본문보다 크다 — 시안에서 문구는
  /// 워드마크와 폭이 비슷한, 화면의 주인공 중 하나다.
  static const taglineFontSize = 20.0;

  /// 문구와 워드마크 사이 간격. 시안에서 두 줄의 중심 거리가 48dp 쯤이라, 줄
  /// 높이(문구 32 · 워드마크 53)의 절반씩을 빼면 이 정도가 남는다.
  static const taglineGap = 6.0;

  /// 워드마크('ticket moa' → 'TIMO') 글자 크기.
  static const wordmarkFontSize = 44.0;

  /// 마지막 장면 로고 높이. 로고 비율(약 1.9:1)로 환산하면 360dp 폰에서 폭이
  /// 화면의 41% 가 된다.
  static const logoHeight = 80.0;
}

class SplashStrings {
  SplashStrings._();

  static const tagline = '세상의 모든 티켓을 모아,';

  /// 워드마크 세 장면. 'ticket moa' 에서 T·I·M·O 만 대문자로 남고 나머지가 빠져
  /// 'TIMO' 가 된다. 마지막(로고) 장면은 글자가 없어 여기 없다.
  static const wordmarks = ['ticket moa', 'TIcket MOa', 'TIMO'];
}
