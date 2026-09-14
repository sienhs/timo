/// 인기 아티스트 한 명.
///
/// 이름과 사진만 받는다. 아티스트 상세 화면이 없어 id 를 쓸 곳이 없고, 홈
/// 격자는 이 둘만 그린다. 상세가 생기면 그때 id 를 더한다 — 백엔드에 요청한
/// 아티스트 목록 API 의 응답 모양(`{name, profileImageUrl}`)과 같다.
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
