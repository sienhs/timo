import 'dart:math';

/// 구매 요청에 붙이는 멱등키를 만든다.
///
/// 서버는 이 키로 재시도가 결제를 두 번 일으키지 않게 막는다(백엔드
/// `MarketApi#purchase`). 그래서 **한 번의 구매 시도에 키는 하나**다 — 재시도는
/// 같은 키로 보내야 하고, 다시 사려는 것은 새 키다. 화면이 시도를 시작할 때
/// 한 번 만들어 들고 있는 이유가 이것이다.
///
/// uuid 패키지를 붙이지 않았다. 서버가 요구하는 것은 100자 이하의 문자열이고
/// (형식 제한이 없다) 이 앱에서 키가 필요한 자리는 여기 하나뿐이라, 의존성을
/// 늘릴 이유가 없다.
///
/// 시각(마이크로초)과 난수를 잇는다. 같은 기기에서 같은 마이크로초에 두 번
/// 만들어질 일이 없고, 설령 시계가 되돌아가도 난수가 갈라 준다.
String newIdempotencyKey() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = _random.nextInt(1 << 32).toRadixString(36);
  return '$now-$noise';
}

final _random = Random();
