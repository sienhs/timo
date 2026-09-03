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

  static const completeTitle = '결제가 완료됐어요';
  static const issuingBadgeLabel = '티켓 발행 중';
  static const issuingDescription =
      '티켓 발행에는 1~2분이 걸릴 수 있어요.\n완료되면 알림으로 알려드릴게요.';
  static const viewTicketLabel = '티켓 보러 가기';
  static const goHomeLabel = '홈으로';

  /// 티켓 화면이 아직 없어 목업에서 안내만 띄운다.
  static const viewTicketPendingMessage = '티켓 화면은 준비 중이에요.';

  static const bookerLabel = '예매자 성함';
  static const ticketPriceLabel = '티켓 가격';
  static const bookingFeeLabel = '예매 수수료';
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
    posterAsset: 'assets/images/sample_poster.jpg',
    ticketPrice: 186000,
    bookingFee: 3000,
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
  static const price = AppTheme.seedColor;

  /// 최종 결제 금액 강조색.
  static const total = AppTheme.accentColor;
  static const warning = AppTheme.accentColor;

  static const posterPlaceholder = Color(0xFFE7E9EB);
  static const avatarRing = AppTheme.accentColor;

  static const issuingBadgeBackground = Color(0xFFFDF2D0);
  static const issuingBadgeForeground = Color(0xFFB07B12);
}
