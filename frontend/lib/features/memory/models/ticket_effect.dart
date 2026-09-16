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
  static TicketEffect fromLabel(String label) {
    if (label == '커튼과 스포트라이트') return TicketEffect.curtain;
    return values.firstWhere(
      (e) => e.label == label,
      orElse: () => TicketEffect.none,
    );
  }
}
