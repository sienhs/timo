import 'package:flutter/foundation.dart';

import '../models/performance.dart';
import '../models/seat.dart';
import '../models/zone.dart';

/// 예매 플로우(좌석 선택 → 결제 → 완료)가 공유하는 상태.
///
/// 선택한 좌석이 화면 경계를 넘어 유지돼야 해서 화면 State 에 둘 수 없다.
/// 라우트 위에 [BookingScope] 로 올려두고 여러 화면이 같은 인스턴스를 본다.
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
  BookingController({
    required this.performance,
    required this.zones,
    required this.seatRowsByZone,
  });

  final Performance performance;
  final List<Zone> zones;

  /// 구역 → 열 → 좌석. 목업에서는 불변이며, 조회는 [seatRowsOf] 를 쓴다.
  final Map<String, List<List<Seat>>> seatRowsByZone;

  Seat? _selectedSeat;

  Seat? get selectedSeat => _selectedSeat;

  Zone zoneById(String id) => zones.firstWhere((zone) => zone.id == id);

  List<List<Seat>> seatRowsOf(String zoneId) => seatRowsByZone[zoneId]!;

  /// 구역별 잔여 좌석 수. 목업에서 좌석 목록은 바뀌지 않으므로 빌드마다
  /// 세지 않고 최초 접근 때 한 번만 계산한다.
  late final Map<String, int> _availableCounts = {
    for (final zone in zones)
      zone.id: seatRowsOf(zone.id)
          .fold(0, (sum, row) => sum + row.where((s) => s.isSelectable).length),
  };

  int availableCountOf(String zoneId) => _availableCounts[zoneId]!;

  bool isSoldOut(String zoneId) => availableCountOf(zoneId) == 0;

  /// 결제 금액 = 정가 + 예매 수수료. 선택한 좌석이 없으면 null.
  ///
  /// 시안의 좌석 선택 하단 바에는 123,000원으로 적혀 있으나 좌석 가격
  /// (186,000원)·결제 화면 합계(189,000원)와 맞지 않는다. 결제 화면 쪽을
  /// 기준으로 삼아 한 곳에서만 계산한다.
  int? get payableAmount {
    final seat = _selectedSeat;
    if (seat == null) return null;
    return zoneById(seat.zoneId).price + performance.bookingFee;
  }

  /// 좌석을 고른다.
  ///
  /// 요구사항의 "한 계정은 하나의 공연에서 티켓을 1매만 보유할 수 있다"에
  /// 따라 선택 목록이 아니라 단일 필드를 덮어쓴다. 새로 고르면 이전 선택은
  /// 자동으로 풀린다.
  void selectSeat(Seat seat) {
    if (!seat.isSelectable) return;
    _selectedSeat = seat;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedSeat == null) return;
    _selectedSeat = null;
    notifyListeners();
  }
}
