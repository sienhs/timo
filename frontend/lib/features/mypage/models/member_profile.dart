/// 마이페이지가 보여 주는 내 정보. 서버 `MemberMeResponseDto` 에서 화면에
/// 필요한 것만 꺼낸다. 실명·전화번호는 로그·스냅샷에 새지 않게 담지 않는다.
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
