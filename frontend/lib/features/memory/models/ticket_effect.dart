/// Stage effect rendered over the ticket front. Legacy persisted labels remain
/// readable through [fromLabel].
enum TicketEffect {
  confetti('꽃가루'),
  laser('레이저'),
  stageLights('무대 조명'),
  curtain('스포트라이트'),
  godRays('빛줄기'),
  none('효과 없음');

  const TicketEffect(this.label);
  final String label;

  /// 서버가 쓰는 이름(`stageLights`)으로 찾는다. 상수 이름이 곧 서버 ENUM 값이라
  /// 이름만 맞춰 두면 양쪽이 같이 움직인다(백엔드 `GoodsEffect`). 모르는 이름은
  /// [none] 이다 — 서버에 값이 하나 늘었다고 소장품이 안 열릴 이유는 없다.
  static TicketEffect fromWire(String? name) =>
      values.firstWhere((e) => e.name == name, orElse: () => none);
  static TicketEffect fromLabel(String label) {
    if (label == '커튼과 스포트라이트') return TicketEffect.curtain;
    return values.firstWhere(
      (e) => e.label == label,
      orElse: () => TicketEffect.none,
    );
  }
}
