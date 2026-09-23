/// 공연 알림 신청 문구.
class AlarmStrings {
  AlarmStrings._();

  /// 신청 상태 응답이 우리가 아는 모양이 아닐 때(프록시가 HTML 을 준 경우 등).
  static const unreadableResponse = '알림 신청 상태를 읽지 못했어요.';

  /// 서버가 문구를 주지 못하고 실패했을 때.
  static const toggleFailed = '알림 신청을 저장하지 못했어요. 잠시 후 다시 시도해주세요.';
}
