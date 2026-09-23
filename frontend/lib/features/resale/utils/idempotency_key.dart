import 'dart:math';

/// 구매 요청에 붙이는 멱등키. 한 번의 구매 시도에 하나다 — 재시도는 같은 키,
/// 다시 사려는 것은 새 키. 다만 서버가 아직 키를 저장하지 않아 같은 키로 두 번
/// 보내면 두 번 처리된다. 이중 결제를 실제로 막는 것은 구매 화면의 버튼 잠금
/// (`ListingPurchaseScreen._purchasing`)이니 걷어내면 안 된다. 시각과 난수를 잇는다.
String newIdempotencyKey() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = _random.nextInt(1 << 32).toRadixString(36);
  return '$now-$noise';
}

final _random = Random();
