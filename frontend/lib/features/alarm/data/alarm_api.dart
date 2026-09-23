import '../models/alarm_status.dart';

/// 공연 알림 신청(`/api/v1/alarms`)을 서버에 남기고 읽는 일. 찜과는 별개다.
/// 예매 오픈·양도 매물 알림은 서버가 이 신청 목록을 보고 보낸다.
/// 구현은 `HttpAlarmApi`(서버)·`MockAlarmApi`(테스트), 실패는 `ApiException`.
/// 모든 주소가 로그인을 요구하므로 로그아웃 상태로 부르면 401 이다.
abstract class AlarmApi {
  /// 이 공연에 대한 내 신청 상태. 없는 공연이어도 둘 다 꺼진 상태로 온다.
  Future<AlarmStatus> fetchStatus(int concertId);

  /// 신청한다. 이미 신청했어도 성공이다(서버가 멱등).
  Future<void> subscribe(int concertId, AlarmType type);

  /// 신청을 푼다. 신청하지 않았어도 성공이다(서버가 멱등).
  Future<void> unsubscribe(int concertId, AlarmType type);
}
