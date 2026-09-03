/// 서버가 내려주는 좌석 상태.
///
/// 요구사항에는 '선점 중'(다른 회원이 잡고 있는 상태)도 있지만, 시안 범례가
/// 예매가능/선택됨/예매완료 3종이라 목업에서는 노출하지 않는다. 서버를 붙일
/// 때 `held` 를 다시 추가하고 [SeatCellState] 와 범례도 함께 늘려야 한다.
///
/// '선택됨'이 여기 없는 게 의도다. 내가 고른 좌석은 서버 상태가 아니라
/// 내 세션의 상태이므로 [Seat] 을 불변으로 두고 BookingController 가
/// selectedSeatId 를 따로 들고 있는다.
enum SeatStatus { available, sold }

class Seat {
  const Seat({
    required this.zoneId,
    required this.row,
    required this.number,
    required this.status,
  });

  final String zoneId;
  final int row;
  final int number;
  final SeatStatus status;

  String get id => '$zoneId-$row-$number';

  /// 'A구역 9열 6번' — 확인 다이얼로그·하단 바·결제 화면에서 공통으로 쓴다.
  String get label => '$zoneId구역 $row열 $number번';

  bool get isSelectable => status == SeatStatus.available;
}

/// 좌석 한 칸을 실제로 그릴 때의 최종 상태.
/// 서버 상태([SeatStatus])와 내 선택을 합쳐 만든다. 시안 범례와 같은 3종이다.
enum SeatCellState { available, selected, sold }

/// 서버 상태와 내 선택을 합쳐 표시 상태를 만든다.
///
/// 좌석 칸마다 컨트롤러를 구독하면 수백 개의 의존 위젯이 생기므로,
/// 선택된 좌석 id 하나만 아래로 내려보내고 계산은 여기서 한다.
SeatCellState seatCellStateOf(Seat seat, String? selectedSeatId) =>
    switch (seat.status) {
      SeatStatus.sold => SeatCellState.sold,
      SeatStatus.available => seat.id == selectedSeatId
          ? SeatCellState.selected
          : SeatCellState.available,
    };
