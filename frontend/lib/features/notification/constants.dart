/// 알림함 화면의 문구.
abstract final class NotificationStrings {
  static const title = '알림';
  static const back = '뒤로';

  /// 오른쪽 아래 버튼. 안 읽은 알림이 있을 때만 나타난다.
  static const markAllRead = '모두 읽음';

  static const empty = '아직 도착한 알림이 없어요';
  static const emptyHint = '예매한 공연 소식과 양도 매물을 여기로 알려드려요';

  static const loadFailed = '알림을 불러오지 못했어요';
  static const retry = '다시 시도';

  /// 목록을 이어 받다 실패했을 때. 첫 화면이 이미 떠 있어 전체를 실패로 바꾸지
  /// 않고 아래쪽에만 알린다.
  static const loadMoreFailed = '더 불러오지 못했어요. 눌러서 다시 시도';

  /// 서버가 JSON 이 아닌 것을 줬을 때(프록시가 HTML 을 끼워 넣은 경우 등).
  static const unreadableResponse = '알림을 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
}

/// 알림함 치수.
abstract final class NotificationMetrics {
  static const horizontalPadding = 20.0;

  /// 상단 바. 마이페이지와 같은 높이다.
  static const topBarHeight = 56.0;
  static const topBarIconSize = 24.0;

  /// 알림 한 건의 위아래 여백.
  static const tileVerticalPadding = 16.0;

  /// 본문 글자. 안 읽은 알림은 [unreadBodyWeight] 로 굵어진다.
  static const bodyFontSize = 15.0;

  /// 줄간격. 두 줄짜리 본문이 붙어 보이지 않을 만큼 띄운다.
  static const bodyLineHeight = 1.45;

  /// 본문과 시각 사이.
  static const bodyToTimeGap = 6.0;
  static const timeFontSize = 12.0;

  /// 안 읽음 점과, 점이 차지하는 칸의 너비.
  ///
  /// 읽은 알림도 이 칸을 비워서 남긴다. 점이 사라질 때 본문이 왼쪽으로 밀리면
  /// 목록을 훑을 때 글줄이 들쭉날쭉해 보인다.
  static const unreadDotSize = 8.0;
  static const unreadDotColumnWidth = 18.0;

  /// 점을 본문 첫 줄의 한가운데에 맞추려고 내리는 만큼.
  ///
  /// 첫 줄의 높이에서 점 크기를 뺀 절반이다. 글자 크기나 줄간격을 바꾸면 이 값도
  /// 따라 바뀌어야 해서 직접 적지 않고 계산해 둔다.
  static const unreadDotTopInset =
      (bodyFontSize * bodyLineHeight - unreadDotSize) / 2;

  /// 오른쪽 아래 '모두 읽음' 버튼과 목록 사이. 버튼이 마지막 알림을 가리지 않게
  /// 목록 끝에 이만큼 빈자리를 둔다.
  static const bottomActionClearance = 88.0;

  /// 목록 끝에서 이만큼 남았을 때 다음 쪽을 미리 불러온다. 끝에 닿고 나서
  /// 부르면 빈 화면을 보며 기다리게 된다.
  static const loadMoreThreshold = 320.0;
}
