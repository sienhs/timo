/// 공연에 서는 아티스트 한 명.
/// 홈의 `ArtistSummary` 와 필드가 같지만 바뀌는 이유가 달라 합치지 않는다.
class ShowArtist {
  const ShowArtist({required this.name, this.photoUrl});

  /// 공연 상세 응답의 아티스트 한 건을 읽는다.
  factory ShowArtist.fromJson(Map<String, dynamic> json) => ShowArtist(
    name: json['name'] as String,
    photoUrl: json['profileImageUrl'] as String?,
  );

  final String name;

  /// 프로필 사진 주소. 없는 아티스트는 null 이고, 이 경우 이름 첫 글자로
  /// 대체한다.
  final String? photoUrl;
}
