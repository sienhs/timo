/// 아티스트 한 명. 홈 인기 격자와 검색의 관련 아티스트 한 줄이 같이 쓴다.
///
/// 이름과 사진만 받는다. 아티스트 상세 화면이 없어 id 를 쓸 곳이 없고, 홈
/// 격자는 이 둘만 그린다. 상세가 생기면 그때 id 를 더한다.
///
/// 백엔드 `ArtistSummaryResponseDto` 는 사진을 `profileImage` 로 준다. 아직
/// 저장소 key 가 아니라 저장된 값 그대로라 그대로 주소로 쓴다 — 프로필이
/// S3 로 옮겨지면 서버가 URL 로 바꿔 내려 주기로 했다.
class ArtistSummary {
  const ArtistSummary({required this.name, this.profileImageUrl});

  factory ArtistSummary.fromJson(Map<String, dynamic> json) => ArtistSummary(
    name: json['name'] as String,
    profileImageUrl: json['profileImage'] as String?,
  );

  final String name;

  /// 프로필 사진 주소. 없으면 이름 첫 글자로 대체한다.
  final String? profileImageUrl;
}
