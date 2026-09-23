/// 아티스트 한 명. 홈 인기 격자와 검색의 관련 아티스트 한 줄이 같이 쓴다.
/// 아티스트 상세가 없어 id 는 받지 않는다. 백엔드 `ArtistSummaryResponseDto` 의
/// 사진은 저장소 key 또는 완전한 URL 이라 `ApiClient.imageUrl` 이 처리한다.
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
