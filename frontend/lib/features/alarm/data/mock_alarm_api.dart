import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/alarm_status.dart';
import 'alarm_api.dart';

/// 서버 없이 도는 [AlarmApi]. 위젯 테스트에 쓴다.
/// 공연별 신청 상태를 메모리에 들고 신청·해제를 그대로 반영한다.
/// [failing] 을 켜면 모든 요청이 실패한다. 먼저 바꿔 둔 버튼이 되돌아가는지 볼 때 쓴다.
class MockAlarmApi implements AlarmApi {
  MockAlarmApi({
    Map<int, AlarmStatus> statuses = const {},
    this.latency = Duration.zero,
    this.failing = false,
  }) : _statuses = {...statuses};

  final Map<int, AlarmStatus> _statuses;

  final Duration latency;

  bool failing;

  /// 서버가 들고 있는 이 공연의 신청 상태. 테스트가 "서버에도 남았는가" 를 볼 때 읽는다.
  AlarmStatus statusOf(int concertId) =>
      _statuses[concertId] ?? AlarmStatus.none;

  int _sendCount = 0;

  /// 신청·해제가 몇 번 나갔는가. 버튼을 연타해도 한 번만 나가는지 볼 때 읽는다.
  int get sendCount => _sendCount;

  @override
  Future<AlarmStatus> fetchStatus(int concertId) async {
    await _wait();
    return statusOf(concertId);
  }

  @override
  Future<void> subscribe(int concertId, AlarmType type) =>
      _set(concertId, type, on: true);

  @override
  Future<void> unsubscribe(int concertId, AlarmType type) =>
      _set(concertId, type, on: false);

  Future<void> _set(int concertId, AlarmType type, {required bool on}) async {
    _sendCount++;
    await _wait();
    _statuses[concertId] = statusOf(concertId).copyWith(type, on: on);
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failing) throw const ApiException(AlarmStrings.toggleFailed);
  }
}
