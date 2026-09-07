/// 홈 상단 캐러셀의 배너 한 장.
///
/// 지금은 공연 하나를 그대로 홍보하는 형태라 [showId] 로 공연을 가리키지만,
/// 이벤트·공지 배너가 생기면 대상이 공연이 아닐 수 있어 별도 모델로 둔다.
class HomeBanner {
  const HomeBanner({
    required this.showId,
    required this.title,
    required this.subtitle,
    required this.posterAsset,
  });

  final String showId;
  final String title;

  /// 제목 아래 한 줄. 시안은 공연장 이름이 들어가 있다.
  final String subtitle;

  final String posterAsset;
}
