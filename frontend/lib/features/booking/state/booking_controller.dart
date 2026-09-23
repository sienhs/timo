import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../models/performance.dart';
import '../models/seat.dart';
import '../models/seat_hold.dart';
import '../models/zone.dart';

/// 예매 플로우(구역 선택 → 좌석 선택 → 결제 → 완료)가 공유하는 상태.
///
/// 선택한 좌석이 화면 경계를 넘어 유지돼야 해서 화면 State 에 둘 수 없다.
/// 라우트 위에 [BookingScope] 로 올려두고 여러 화면이 같은 인스턴스를 본다.
///
/// **구역·좌석 목록은 여기 없다.** 서버에서 받아 오는 것은 그것을 그리는 화면이
/// 들고 있고(홈·내 티켓과 같은 방식), 여기에는 화면이 바뀌어도 남아야 하는 것
/// — 어느 공연을 예매 중인지, 어느 자리를 골랐는지 — 만 둔다. 목록까지 들고
/// 있으면 새로고침할 때마다 누가 주인인지 헷갈린다.
///
/// 선점 카운트다운은 **의도적으로** 여기 없다. 좌석 선택 화면에는 두지 않고
/// 결제 화면에만 두기로 정했다(HoldCountdownButton, S15P21D206-139).
/// 좌석을 고르는 동안 시간에 쫓기게 만들지 않겠다는 판단이므로, 좌석 선택에
/// 타이머가 빠진 것을 누락으로 보고 되살리지 않는다.
///
/// 만약 되살릴 일이 생기면, 남은 시간은 이 ChangeNotifier 가 아니라 별도의
/// ValueNotifier 로 노출해야 한다. 매초 notifyListeners 를 부르면 좌석
/// 수백 칸이 매초 리빌드된다.
class BookingController extends ChangeNotifier {
  BookingController({required Performance performance}) {
    _performance = performance;
  }

  late Performance _performance;

  /// 화면 위쪽에 찍는 공연 정보.
  ///
  /// 상세 화면이 예매를 시작하면서 [startBooking] 으로 넣어 준다. 그 전에는
  /// 앱이 만들 때 준 값이 들어 있다 — 흐름 밖에서 열린 화면(딥링크, 화면 단위
  /// 테스트)이 빈 머리말을 그리지 않게 하는 자리다.
  Performance get performance => _performance;

  int _concertId = BookingConstants.fallbackConcertId;

  /// 서버가 준 공연 번호. 구역·좌석·선점 요청이 전부 이 번호를 함께 보낸다.
  int get concertId => _concertId;

  Seat? _selectedSeat;
  Zone? _selectedZone;
  SeatHold? _hold;
  String? _bookerName;

  Seat? get selectedSeat => _selectedSeat;

  /// 결제 화면에 찍을 예매자 실명. 아직 못 받았으면 null.
  ///
  /// 자리를 잡을 때 좌석 화면이 함께 받아 `setBookerName` 으로 넣어 준다
  /// (`SeatSelectionScreen._onCheckout`). 이 컨트롤러는 예매 흐름 하나와 함께
  /// 사라지므로, 실명이 머무는 곳도 그 흐름뿐이다 — 세션이나 마이페이지 모델에
  /// 얹지 않기로 한 것과 같은 이유다(`MyPageApi.fetchBookerName`).
  String? get bookerName => _bookerName;

  /// 서버에 잡아 둔 자리. 아직 잡지 않았으면 null.
  ///
  /// 고른 자리([selectedSeat])와 다르다. 고르는 것은 앱 안의 일이고, 잡는 것은
  /// 결제로 넘어갈 때 서버에 요청해 5분을 확보하는 일이다. 결제 화면의
  /// 카운트다운이 이 값의 만료 시각을 센다.
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
  ///
  /// 시안의 좌석 선택 하단 바에는 123,000원으로 적혀 있으나 좌석 가격
  /// (186,000원)과 맞지 않는다. 결제 화면과 같은 값을 찍는다.
  int? get payableAmount => _selectedZone?.price;

  /// 어느 공연을 예매하는지 정한다.
  ///
  /// 상세 화면이 예매로 들어가면서 공연 번호와 함께 [performance] 를 넘긴다.
  /// 구역 화면도 들어올 때 번호만 다시 넣는데, 흐름 밖에서 바로 열린 경우
  /// (딥링크, 화면 단위 테스트) 그 번호라도 정해져야 하기 때문이다.
  ///
  /// 다른 공연으로 바꿔 들어오면 앞서 고른 자리를 버린다. 그대로 두면 A 공연의
  /// 좌석을 B 공연 결제 화면이 그리게 된다.
  ///
  /// **알림을 보내지 않는다.** 화면이 세워지는 중(initState)에도 불리는데 거기서
  /// 리스너를 깨우면 빌드 도중 리빌드를 걸게 된다. 이 시점에는 고른 자리를
  /// 보고 있는 화면도 없다 — 예매를 막 시작한 참이기 때문이다.
  void startBooking(int concertId, {Performance? performance}) {
    if (performance != null) _performance = performance;
    if (_concertId == concertId) return;
    _concertId = concertId;
    _selectedSeat = null;
    _selectedZone = null;
  }

  /// 구역 화면에 들어왔다. 다른 구역에서 고른 자리는 버린다.
  ///
  /// [startBooking] 이 공연에 대해 하는 일을 구역에 대해 한다. **고른 자리는
  /// 예매 흐름 하나가 공유하는데 구역 화면은 구역마다 새로 열린다.** 여기서
  /// 비우지 않으면 A구역 배치도를 보면서 하단 바에는 B구역 자리가 적힌 채로
  /// 결제까지 갈 수 있다(실제로 그렇게 됐다).
  ///
  /// 잡아 둔 자리도 같이 놓는다. 그 자리를 잡았던 화면은 이미 사라졌고,
  /// 사라지면서 서버 쪽 선점도 풀었다.
  ///
  /// **알림을 보내지 않는다.** 화면이 세워지는 중(initState)에 불리는데 거기서
  /// 리스너를 깨우면 빌드 도중 리빌드를 걸게 된다 — [startBooking] 과 같은 이유다.
  void enterZone(int zoneId) {
    final zone = _selectedZone;
    if (zone == null || zone.id == zoneId) return;
    _selectedSeat = null;
    _selectedZone = null;
    _hold = null;
  }

  /// 좌석을 고른다.
  ///
  /// 요구사항의 "한 계정은 하나의 공연에서 티켓을 1매만 보유할 수 있다"에
  /// 따라 선택 목록이 아니라 단일 필드를 덮어쓴다. 새로 고르면 이전 선택은
  /// 자동으로 풀린다. 서버의 선점 규칙도 같다.
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

  /// 받아 온 예매자 실명을 넣는다. 못 받았으면(요청 실패) 부르지 않는다.
  ///
  /// **알림을 보내지 않는다.** 이 값을 그리는 화면은 결제 화면뿐이고, 그 화면은
  /// 아직 열리지도 않았다. 지금 리스너를 깨우면 좌석 수백 칸이 한 번 더
  /// 리빌드될 뿐이다 — 바로 뒤에 불리는 [holdSeat] 의 알림으로 충분하다.
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
