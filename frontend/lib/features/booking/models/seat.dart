/// 배치도에 보이는 좌석 상태. 요청한 공연 기준으로 그때그때 계산돼 온다.
/// '선택됨' 은 서버 상태가 아니라 내 세션의 상태라 여기 없고, BookingController 가
/// 고른 좌석을 따로 들고 있는다.
enum SeatStatus {
  /// 예매 가능. 이 공연에 대한 유효한 선점도 주문도 없다.
  available,

  /// 다른 회원이 잡고 있다. 5분이 지나면 저절로 풀린다.
  held,

  /// 판매 완료.
  sold,
}

/// 서버가 준 상태 문자열을 앱 상태로 바꾼다. 모르는 값은 [SeatStatus.sold] 로
/// 본다 — 팔 수 없는 자리를 팔 수 있는 것처럼 보이는 것보다 안전하다.
SeatStatus seatStatusOf(Object? raw) => switch (raw) {
  'AVAILABLE' => SeatStatus.available,
  'HELD' => SeatStatus.held,
  _ => SeatStatus.sold,
};

/// 좌석 한 자리. 구역 이름은 담지 않는다. 이름이 필요한 문구는 `Zone.seatLabel`
/// 이 만든다.
class Seat {
  const Seat({
    required this.id,
    required this.row,
    required this.number,
    required this.status,
  });

  factory Seat.fromJson(Map<String, dynamic> json) => Seat(
    id: (json['id'] as num).toInt(),
    row: (json['seatNo'] as num).toInt(),
    number: (json['seatCol'] as num).toInt(),
    status: seatStatusOf(json['status']),
  );

  /// 서버가 준 좌석 번호. 선점·취소는 이 번호로 요청한다.
  final int id;

  /// 몇 열인지(서버의 `seatNo`).
  final int row;

  /// 그 열에서 몇 번째인지(서버의 `seatCol`).
  final int number;

  final SeatStatus status;

  bool get isSelectable => status == SeatStatus.available;
}

/// 좌석 한 칸을 실제로 그릴 때의 최종 상태.
/// 서버 상태([SeatStatus])와 내 선택을 합쳐 만든다. 시안 범례와 같은 3종이다.
enum SeatCellState { available, selected, sold }

/// 서버 상태와 내 선택을 합쳐 표시 상태를 만든다. 선점중은 예매완료와 같은
/// 회색이다. 순서가 중요하다 — 팔린 자리가 가장 세고, 그다음이 내 선택이다.
/// 내가 잡은 자리도 서버에는 선점중으로 오므로 상태만 보고 칠하면 방금 고른
/// 자리가 회색이 된다. 칸마다 컨트롤러를 구독하지 않고 선택된 좌석 id 만 받는다.
SeatCellState seatCellStateOf(Seat seat, int? selectedSeatId) {
  if (seat.status == SeatStatus.sold) return SeatCellState.sold;
  if (seat.id == selectedSeatId) return SeatCellState.selected;
  return seat.status == SeatStatus.held
      ? SeatCellState.sold
      : SeatCellState.available;
}
