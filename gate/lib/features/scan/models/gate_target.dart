/// 이 단말이 검표하는 공연.
///
/// 헤더에 표시되고, 검증 요청마다 서버에 함께 간다(다른 공연 티켓을 서버가
/// 가려내는 근거). 지금은 앱이 목 값을 하나 들고 시작한다. 운영자 로그인·공연
/// 선택이 붙으면 그 화면이 이 값을 만들어 스캔 화면에 넘긴다.
class GateTarget {
  const GateTarget({required this.concertId, required this.concertTitle});

  final int concertId;
  final String concertTitle;
}
