/// 로딩(스플래시) 화면의 문구·시간·크기 상수.
/// 네 장면의 순서와 머무는 시간을 한 곳에 두어 화면 코드와 테스트가 같은 값을 본다.
class SplashMetrics {
  SplashMetrics._();

  /// 장면이 머무는 시간. 순서대로 로딩 1·2·3·4, 합쳐서 2.5초.
  /// 첫 장면은 눈이 닿을 시간을 줘 조금 길고, 마지막 로고는 브랜드가 남도록 가장 길다.
  static const stepDurations = [
    Duration(milliseconds: 600),
    Duration(milliseconds: 500),
    Duration(milliseconds: 500),
    Duration(milliseconds: 900),
  ];

  /// 장면이 바뀔 때의 크로스페이드 길이. 머무는 시간 **안에** 들어가므로
  /// 장면이 온전히 보이는 시간은 머무는 시간에서 이만큼을 뺀 값이다.
  static const fadeDuration = Duration(milliseconds: 200);

  /// 첫 장면이 뜬 순간부터 홈으로 넘어가기까지. 테스트가 이만큼 시간을 돌린다.
  static final totalDuration = stepDurations.fold<Duration>(
    Duration.zero,
    (sum, step) => sum + step,
  );

  // 크기는 시안 이미지의 비율에 맞췄다.

  /// 문구('세상의 모든 티켓을 모아,') 글자 크기. 본문보다 크다.
  static const taglineFontSize = 20.0;

  /// 문구와 워드마크 사이 간격.
  static const taglineGap = 6.0;

  /// 워드마크('ticket moa' → 'TIMO') 글자 크기.
  static const wordmarkFontSize = 44.0;

  /// 마지막 장면 로고 높이.
  static const logoHeight = 80.0;
}

class SplashStrings {
  SplashStrings._();

  static const tagline = '세상의 모든 티켓을 모아,';

  /// 워드마크 세 장면. 'ticket moa' 에서 T·I·M·O 만 대문자로 남고 나머지가 빠져
  /// 'TIMO' 가 된다. 마지막(로고) 장면은 글자가 없어 여기 없다.
  static const wordmarks = ['ticket moa', 'TIcket MOa', 'TIMO'];
}
