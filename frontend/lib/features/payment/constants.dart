import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'models/ticket_order.dart';

/// 결제 도메인의 문구·시간 상수.
///
/// 숫자와 그 숫자를 설명하는 문구를 같은 곳에 두어 한쪽만 바뀌는 일을 막는다.
class PaymentConstants {
  PaymentConstants._();

  /// 좌석이 선점된 상태로 유지되는 시간. 경고 문구도 이 값에서 파생시킨다.
  static const holdDuration = Duration(minutes: 5);

  /// 남은 시간 표시를 갱신하는 주기.
  static const countdownTick = Duration(seconds: 1);

  static const payScreenTitle = '결제하기';
  static const payActionLabel = '결제하기';

  /// `holdDuration`이 바뀌면 문구의 분 수도 함께 바뀐다.
  static String get holdWarning =>
      '${holdDuration.inMinutes}분안에 결제하지 않으면 자리가 넘어가요!';

  /// 주문을 만들려는데 로그인이 풀려 있을 때(401). 좌석을 잡을 때와 같은 문구다.
  static const loginRequired = '로그인이 필요해요.';

  // 주문이 거절되는 이유들. 서버 문구를 그대로 쓰지 않는 이유는
  // `BookingServerErrors` 주석에 있다 — `(concertId=3)` 같은 디버깅용 꼬리가
  // 붙어 있어 사용자에게 보여줄 것이 못 된다.
  //
  // 좌석 화면(`BookingStrings`)에도 뜻이 겹치는 문구가 있지만 합치지 않는다.
  // 저쪽은 아직 자리를 고르는 중이고 이쪽은 이미 잡아 둔 자리로 결제를 누른
  // 뒤라, 같은 이유라도 다음에 할 일이 다르다.

  /// 잡아 둔 5분이 지났을 때(409). 자리는 이미 풀려 남이 가져갔을 수 있다.
  static const holdExpired = '자리를 잡아 둔 시간이 지났어요. 다시 골라주세요.';

  /// 남이 잡고 있는 자리로 주문을 만들려 했을 때(403).
  ///
  /// 정상 흐름에서는 나오기 어렵다. 내 선점이 만료된 뒤 남이 그 자리를 가져간
  /// 다음에 결제를 누른 경우다.
  static const holdNotOwned = '다른 분이 잡고 있는 자리예요. 다시 골라주세요.';

  /// 이 공연의 티켓을 이미 가지고 있을 때(409). 한 공연에 한 장이다.
  static const alreadyReserved = '이미 이 공연의 티켓을 가지고 있어요. 한 공연에 한 장만 살 수 있어요.';

  /// 예매 중인 공연이 아닐 때(409). 오픈 전·매진·종료·취소가 전부 여기로 온다.
  static const concertNotOnSale = '지금은 예매할 수 있는 공연이 아니에요.';

  /// 완료 화면이 발행 진행 상태를 다시 묻는 주기.
  ///
  /// 서버는 체인 트랜잭션 두 개(잔액 차감 · 발행)가 확정되기를 기다린다.
  /// 로컬 하드햇 기준 몇 초라, 이보다 잦게 물으면 서버만 두드린다.
  static const issuePollInterval = Duration(seconds: 3);

  /// 발행 상태 묻기를 그만두는 시점.
  ///
  /// 이 뒤에도 안 끝났으면 화면은 "발행 중" 그대로 두고 더 묻지 않는다. 결과는
  /// 내 티켓에서 확인하면 된다. 서버가 발행에 실패하면 주문을 되돌리는 데도
  /// 시간이 걸려, 너무 일찍 그만두면 실패를 못 보여 준다.
  static const issuePollTimeout = Duration(minutes: 2);

  static const completeTitle = '결제가 완료됐어요';

  // 발행 진행 상태 배지와 그 아래 안내. 시안에는 '발행 중' 하나만 있다. 완료와
  // 실패는 같은 자리에 같은 모양으로, 색과 문구만 바꿔 보여 준다.
  static const issuingBadgeLabel = '티켓 발행 중';
  static const issuedBadgeLabel = '티켓 발행 완료';
  static const issueFailedBadgeLabel = '티켓 발행 실패';
  static const issuingDescription =
      '티켓 발행에는 1~2분이 걸릴 수 있어요.\n완료되면 알림으로 알려드릴게요.';
  static const issuedDescription = '티켓이 발행됐어요.\n내 티켓에서 바로 확인할 수 있어요.';

  /// 잔액 차감이나 발행이 실패한 경우다. 서버가 차감했던 금액을 되돌리고 주문을
  /// 취소한다. 실패 사유는 서버 내부 문구라 여기 찍지 않는다.
  static const issueFailedDescription = '티켓 발행에 실패했어요.\n결제된 금액은 자동으로 환불돼요.';

  static const viewTicketLabel = '티켓 보러 가기';
  static const goHomeLabel = '홈으로';

  static const bookerLabel = '예매자 성함';
  static const ticketPriceLabel = '티켓 가격';
  static const totalLabel = 'TOTAL';
  static const concertLabel = '공연명';
  static const performedAtLabel = '일시';
  static const seatLabel = '좌석';
  static const paidAmountLabel = '결제 금액';

  /// 발표용 더미 주문. 서버 연동 시 이 상수를 지우고 응답으로 교체한다.
  static final sampleOrder = TicketOrder(
    concertTitle: '2026 아이유 콘서트',
    performedAt: DateTime(2026, 11, 4, 18, 0),
    venue: '고척스카이돔',
    seat: 'A구역 9열 6번',
    bookerName: '홍길동',
    ticketPrice: 186000,
  );
}

/// 결제 화면 디자인에 쓰는 색.
///
/// 지금은 이 도메인만 쓰므로 도메인 안에 둔다. 다른 화면이 같은 이유로 쓰게 되면
/// `AppTheme`으로 승격한다.
class PaymentColors {
  PaymentColors._();

  static const page = Color(0xFFF4F5F6);
  static const card = Colors.white;
  static const divider = Color(0xFFEFF0F1);
  static const cardShadow = Color(0x0F000000);

  static const label = Color(0xFF8C9196);
  static const value = Color(0xFF1F2124);

  /// 티켓 가격·수수료 강조색. 브랜드 그린을 그대로 쓴다.
  ///
  /// 시안에서는 이 두 값이 검은 글자이고 로즈는 TOTAL 에만 쓰였다. 개별 항목
  /// (초록)과 최종 결제 금액(코랄)을 색으로 구분하기로 **정한 것**이므로,
  /// 시안과 다른 것을 이탈로 보고 되돌리지 않는다.
  static const price = AppTheme.seedColor;

  /// 최종 결제 금액 강조색.
  static const total = AppTheme.accentColor;
  static const warning = AppTheme.accentColor;

  static const posterPlaceholder = Color(0xFFE7E9EB);
  static const avatarRing = AppTheme.accentColor;

  // 발행 상태 배지. 옅은 바탕에 진한 글자로, 세 상태가 같은 결이다. 글자가
  // 작아(12px) 브랜드 초록·코랄을 그대로 쓰면 바탕과 대비가 모자라 한 단계
  // 진하게 잡았다.
  static const issuingBadgeBackground = Color(0xFFFDF2D0);
  static const issuingBadgeForeground = Color(0xFFB07B12);
  static const issuedBadgeBackground = Color(0xFFDDF3E7);
  static const issuedBadgeForeground = Color(0xFF0F7A47);
  static const issueFailedBadgeBackground = Color(0xFFFCE4E1);
  static const issueFailedBadgeForeground = Color(0xFFC0392B);
}
