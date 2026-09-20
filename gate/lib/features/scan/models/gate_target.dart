/// 이 단말이 검표하는 공연.
///
/// 스캔 화면 헤더에 표시되고, 검증 요청마다 [concertId] 가 서버에 함께 간다
/// (다른 공연 티켓을 서버가 가려내는 근거). 공연 선택 화면에서 고른 공연을
/// 앱(App)이 이 형태로 바꿔 스캔 화면에 넘긴다.
///
/// 공연 목록 모델(`ConcertSummary`)을 그대로 받지 않는 이유: 스캔 화면이
/// 아는 것은 "어느 공연을, 헤더에 뭐라고 적고" 둘뿐이다. 포스터·날짜 원본은
/// 필요 없고, 목록 모델이 바뀔 때 스캔 화면까지 흔들릴 이유도 없다.
class GateTarget {
  const GateTarget({
    required this.concertId,
    required this.concertTitle,
    this.venueName = '',
    this.whenLabel = '',
  });

  final int concertId;
  final String concertTitle;

  /// 헤더 둘째 줄. 비어 있으면 그 줄을 그리지 않는다.
  final String venueName;
  final String whenLabel;

  /// 헤더 둘째 줄에 적을 문구. `공연장 · 일시`. 둘 중 없는 것은 뺀다.
  String get subtitle =>
      [venueName, whenLabel].where((part) => part.isNotEmpty).join(' · ');
}
