import '../models/alarm_status.dart';

/// 공연 알림 신청(`/api/v1/alarms`)을 서버에 남기고 읽는 일.
///
/// 알림 신청은 찜과 별개다. 찜을 하거나 풀어도 알림 신청은 바뀌지 않는다.
/// 예매 오픈·양도 매물 알림은 서버가 이 신청 목록을 보고 보낸다.
///
/// 화면은 이 약속만 알고, 실제로 서버에 가는지(`HttpAlarmApi`) 메모리에서
/// 흉내 내는지(`MockAlarmApi`) 는 앱이 정한다. `FavoriteApi` 와 같은 구조다.
///
/// 반환 규칙: 성공하면 값을, 실패(네트워크·서버 오류)는 `ApiException` 으로
/// 던진다. 모든 주소가 로그인을 요구하므로 로그아웃 상태로 부르면 401 이다 —
/// 부르기 전에 로그인 여부를 보는 것은 화면 몫이다.
abstract class AlarmApi {
  /// 이 공연에 대한 내 신청 상태. 없는 공연이어도 둘 다 꺼진 상태로 온다.
  Future<AlarmStatus> fetchStatus(int concertId);

  /// 신청한다. 이미 신청했어도 성공이다(서버가 멱등).
  Future<void> subscribe(int concertId, AlarmType type);

  /// 신청을 푼다. 신청하지 않았어도 성공이다(서버가 멱등).
  Future<void> unsubscribe(int concertId, AlarmType type);
}
