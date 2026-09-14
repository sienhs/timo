/// 배치도에 보이는 좌석 상태.
///
/// 서버가 저장해 둔 값이 아니라 **요청한 공연 기준으로 그때그때 계산돼** 온다.
/// 같은 자리라도 공연이 다르면 상태가 다르다.
///
/// '선택됨' 이 여기 없는 게 의도다. 내가 고른 좌석은 서버 상태가 아니라 내
/// 세션의 상태이므로 [Seat] 을 불변으로 두고 BookingController 가 고른 좌석을
/// 따로 들고 있는다.
enum SeatStatus {
  /// 예매 가능. 이 공연에 대한 유효한 선점도 주문도 없다.
  available,

  /// 다른 회원이 잡고 있다. 5분이 지나면 저절로 풀린다.
  held,

  /// 판매 완료.
  sold,
}

/// 서버가 준 상태 문자열을 앱 상태로 바꾼다.
///
/// 모르는 값은 [SeatStatus.sold] 로 본다. 서버가 상태를 하나 더 늘렸을 때
/// 예매 가능으로 떨어지면 **팔 수 없는 자리를 팔 수 있는 것처럼** 보여주게 된다.
/// 고를 수 없는 쪽으로 틀리는 편이 안전하다.
SeatStatus seatStatusOf(Object? raw) => switch (raw) {
  'AVAILABLE' => SeatStatus.available,
  'HELD' => SeatStatus.held,
  _ => SeatStatus.sold,
};

/// 좌석 한 자리.
///
/// 구역 이름은 담지 않는다. 서버 응답도 좌석마다 구역명을 싣지 않고, 이름이
/// 필요한 문구는 `Zone.seatLabel` 이 만든다.
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

/// 서버 상태와 내 선택을 합쳐 표시 상태를 만든다.
///
/// **선점중은 예매완료와 같은 회색이다.** 시안 범례가 3종이라 네 번째 색을
/// 늘리지 않기로 했다. 둘을 가르지 않아도 사용자가 할 일은 같다 — 고를 수 없는
/// 자리이니 다른 자리를 고르면 된다. 선점이 풀리면 새로고침했을 때 초록으로
/// 돌아온다.
///
/// 순서가 중요하다.
///
/// 1. 팔린 자리가 가장 세다. 내가 고른 뒤 남이 사 간 것을 새로고침으로 알게
///    되는 경우인데, 선택된 색으로 남겨 두면 화면이 거짓말을 한다.
/// 2. 그다음이 내 선택이다. **내가 잡은 자리는 서버에도 선점중으로 보인다** —
///    서버는 누가 잡았는지 알려 주지 않기 때문이다. 상태만 보고 칠하면 방금
///    고른 자리가 회색이 되어 선택이 풀린 것처럼 보인다.
///
/// 좌석 칸마다 컨트롤러를 구독하면 수백 개의 의존 위젯이 생기므로,
/// 선택된 좌석 id 하나만 아래로 내려보내고 계산은 여기서 한다.
SeatCellState seatCellStateOf(Seat seat, int? selectedSeatId) {
  if (seat.status == SeatStatus.sold) return SeatCellState.sold;
  if (seat.id == selectedSeatId) return SeatCellState.selected;
  return seat.status == SeatStatus.held
      ? SeatCellState.sold
      : SeatCellState.available;
}
