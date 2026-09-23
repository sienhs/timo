import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../models/performance.dart';
import '../models/seat.dart';
import '../models/seat_hold.dart';
import '../models/zone.dart';

/// 예매 플로우(구역 선택 → 좌석 선택 → 결제 → 완료)가 공유하는 상태. 라우트 위에
/// [BookingScope] 로 올려두고, 화면이 바뀌어도 남아야 하는 것만 둔다(구역·좌석
/// 목록은 그리는 화면이 든다). 선점 카운트다운은 좌석 선택에 두지 않는다(결제
/// 화면에만). 되살릴 때는 매초 리빌드를 피하도록 별도 ValueNotifier 로 노출한다.
class BookingController extends ChangeNotifier {
  BookingController({required Performance performance}) {
    _performance = performance;
  }

  late Performance _performance;

  /// 화면 위쪽에 찍는 공연 정보. 상세 화면이 [startBooking] 으로 넣어 주고, 그
  /// 전에는 흐름 밖에서 열린 화면이 빈 머리말을 그리지 않게 앱이 준 값이 들어 있다.
  Performance get performance => _performance;

  int _concertId = BookingConstants.fallbackConcertId;

  /// 서버가 준 공연 번호. 구역·좌석·선점 요청이 전부 이 번호를 함께 보낸다.
  int get concertId => _concertId;

  Seat? _selectedSeat;
  Zone? _selectedZone;
  SeatHold? _hold;
  String? _bookerName;

  Seat? get selectedSeat => _selectedSeat;

  /// 결제 화면에 찍을 예매자 실명. 아직 못 받았으면 null. 자리를 잡을 때 좌석
  /// 화면이 함께 받아 `setBookerName` 으로 넣어 준다. 예매 흐름 하나와 함께
  /// 사라지므로 세션이나 마이페이지 모델에는 얹지 않는다.
  String? get bookerName => _bookerName;

  /// 서버에 잡아 둔 자리. 아직 잡지 않았으면 null. 고르는 것([selectedSeat])은
  /// 앱 안의 일이고, 잡는 것은 결제로 넘어갈 때 서버에 5분을 확보하는 일이다.
  SeatHold? get hold => _hold;

  /// 고른 좌석이 속한 구역. 금액과 좌석 이름이 구역에서 나온다.
  Zone? get selectedZone => _selectedZone;

  /// '1층 A블록 9열 6번'. 고른 자리가 없으면 null.
  String? get selectedSeatLabel {
    final seat = _selectedSeat;
    final zone = _selectedZone;
    if (seat == null || zone == null) return null;
    return zone.seatLabel(seat);
  }

  /// 결제 금액. 고른 구역의 정가 그대로다 — 수수료는 없다(`Performance` 주석).
  /// 선택한 좌석이 없으면 null.
  int? get payableAmount => _selectedZone?.price;

  /// 어느 공연을 예매하는지 정한다. 상세 화면이 [performance] 와 함께 넘기고,
  /// 구역 화면도 들어올 때 번호만 다시 넣는다(흐름 밖에서 열린 경우 대비). 다른
  /// 공연으로 바꾸면 앞서 고른 자리를 버린다. initState 에서도 불리므로 알림을
  /// 보내지 않는다 — 빌드 도중 리빌드를 걸게 된다.
  void startBooking(int concertId, {Performance? performance}) {
    if (performance != null) _performance = performance;
    if (_concertId == concertId) return;
    _concertId = concertId;
    _selectedSeat = null;
    _selectedZone = null;
  }

  /// 구역 화면에 들어왔다. 다른 구역에서 고른 자리는 잡아 둔 자리와 함께 버린다.
  /// 비우지 않으면 A구역 배치도를 보면서 하단 바에는 B구역 자리가 적힌 채로
  /// 결제까지 갈 수 있다. initState 에서 불리므로 알림을 보내지 않는다.
  void enterZone(int zoneId) {
    final zone = _selectedZone;
    if (zone == null || zone.id == zoneId) return;
    _selectedSeat = null;
    _selectedZone = null;
    _hold = null;
  }

  /// 좌석을 고른다. 한 계정은 한 공연에 1매만 가질 수 있어 단일 필드를 덮어쓴다.
  /// 새로 고르면 이전 선택은 자동으로 풀린다. 서버의 선점 규칙도 같다.
  void selectSeat(Zone zone, Seat seat) {
    if (!seat.isSelectable) return;
    _selectedSeat = seat;
    _selectedZone = zone;
    // 다른 자리를 고른 순간 앞서 잡아 둔 자리는 의미가 없다. 서버 쪽을 푸는
    // 일은 화면이 맡는다(여기서 요청을 보내면 상태 객체가 네트워크를 알게 된다).
    _hold = null;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedSeat == null) return;
    _selectedSeat = null;
    _selectedZone = null;
    _hold = null;
    notifyListeners();
  }

  /// 받아 온 예매자 실명을 넣는다. 못 받았으면 부르지 않는다. 결제 화면은 아직
  /// 열리지 않았으니 알리지 않는다 — 바로 뒤 [holdSeat] 의 알림으로 충분하다.
  void setBookerName(String name) {
    _bookerName = name;
  }

  /// 서버에 자리를 잡았다. 결제 화면이 남은 시간을 세기 시작한다.
  void holdSeat(SeatHold hold) {
    _hold = hold;
    notifyListeners();
  }

  /// 잡아 둔 자리를 놓았다. 고른 자리는 그대로 둔다 — 자리는 다시 비었으므로
  /// 사용자가 결제하기를 한 번 더 누르면 같은 자리를 다시 잡을 수 있다.
  void clearHold() {
    if (_hold == null) return;
    _hold = null;
    notifyListeners();
  }
}
