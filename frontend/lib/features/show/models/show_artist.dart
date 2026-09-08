/// 공연에 서는 아티스트 한 명.
///
/// 홈의 `ArtistSummary` 와 필드가 같지만 합치지 않는다. 저쪽은 '지금 인기
/// 있는 사람'의 목록이라 순위·팔로워 같은 것이 붙을 자리이고, 이쪽은 '이
/// 공연에 서는 사람'이라 배역·출연 회차가 붙을 자리다. 바뀌는 이유가 달라서,
/// 합치면 한쪽 사정으로 다른 쪽이 흔들린다. (`ShowSummary` 와 `Performance`
/// 를 합치지 않은 것과 같은 판단이다.)
class ShowArtist {
  const ShowArtist({required this.name, this.photoAsset});

  final String name;

  /// 프로필 사진 경로. 에셋이 아직 없어 대부분 null 이고, 이 경우 이름
  /// 첫 글자로 대체한다. 서버 연동 시 URL 로 바뀐다.
  final String? photoAsset;
}
