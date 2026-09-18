/// 아티스트 한 명. 홈 인기 격자와 검색의 관련 아티스트 한 줄이 같이 쓴다.
///
/// 이름과 사진만 받는다. 아티스트 상세 화면이 없어 id 를 쓸 곳이 없고, 홈
/// 격자는 이 둘만 그린다. 상세가 생기면 그때 id 를 더한다.
///
/// 백엔드 `ArtistSummaryResponseDto` 는 사진을 `profileImageUrl` 로 준다. 포스터와
/// 같이 서버의 `ImageStorage` 를 거친 값이라 지금은 저장소 key(상대 경로), S3 로
/// 옮겨지면 완전한 URL 이다. 어느 쪽이든 `ApiClient.imageUrl` 이 처리한다.
class ArtistSummary {
  const ArtistSummary({required this.name, this.profileImageUrl});

  factory ArtistSummary.fromJson(Map<String, dynamic> json) => ArtistSummary(
    name: json['name'] as String,
    profileImageUrl: json['profileImageUrl'] as String?,
  );

  final String name;

  /// 프로필 사진 주소. 없으면 이름 첫 글자로 대체한다.
  final String? profileImageUrl;
}
