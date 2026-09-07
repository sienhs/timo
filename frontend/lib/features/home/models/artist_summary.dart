/// 인기 아티스트 한 명.
class ArtistSummary {
  const ArtistSummary({required this.name, this.photoAsset});

  final String name;

  /// 프로필 사진 경로. 에셋이 아직 없어 대부분 null 이고, 이 경우 이름
  /// 첫 글자로 대체한다. 서버 연동 시 URL 로 바뀐다.
  final String? photoAsset;
}
