/// 마이페이지가 보여 주는 내 정보. 서버 `MemberMeResponseDto` 에서 화면에
/// 필요한 것만 꺼낸 것이다.
///
/// 응답에는 실명·전화번호도 오지만 여기 담지 않는다. 화면이 쓰지 않는
/// 개인정보를 모델에 들고 다니면 로그·스냅샷에 새어 나갈 자리가 늘어난다.
class MemberProfile {
  const MemberProfile({required this.memberId, required this.nickname});

  final int memberId;

  /// 서비스에 노출되는 이름. 인사말에 쓴다.
  final String nickname;

  factory MemberProfile.fromJson(Map<String, dynamic> json) => MemberProfile(
    memberId: (json['memberId'] as num).toInt(),
    nickname: json['nickname'] as String,
  );
}
