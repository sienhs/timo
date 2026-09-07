/// 아이디·닉네임 중복 확인의 진행 상태.
///
/// 입력값이 바뀌면 [unchecked] 로 돌아간다. '다음으로' 는 [available] 일 때만
/// 켜지므로, 확인을 통과한 뒤 글자를 고치면 다시 확인해야 한다.
enum AvailabilityStatus {
  /// 아직 확인하지 않았거나, 확인 뒤 입력이 바뀌었다.
  unchecked,

  /// 서버 응답을 기다리는 중.
  checking,

  /// 사용할 수 있다.
  available,

  /// 이미 다른 사람이 쓰고 있다.
  taken,
}
