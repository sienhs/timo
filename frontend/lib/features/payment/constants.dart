import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'models/ticket_order.dart';

/// 결제 도메인의 문구·시간 상수. 숫자와 그 숫자를 설명하는 문구를 같은 곳에 둔다.
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

  // 주문이 거절되는 이유들. 서버 문구에는 디버깅용 꼬리가 붙어 그대로 쓰지 않고,
  // 좌석 화면(`BookingStrings`)과 뜻이 겹쳐도 다음에 할 일이 달라 합치지 않는다.

  /// 잡아 둔 5분이 지났을 때(409). 자리는 이미 풀려 남이 가져갔을 수 있다.
  static const holdExpired = '자리를 잡아 둔 시간이 지났어요. 다시 골라주세요.';

  /// 남이 잡고 있는 자리로 주문을 만들려 했을 때(403). 내 선점이 만료된 뒤 남이
  /// 그 자리를 가져간 다음에 결제를 누른 경우다.
  static const holdNotOwned = '다른 분이 잡고 있는 자리예요. 다시 골라주세요.';

  /// 이 공연의 티켓을 이미 가지고 있을 때(409). 한 공연에 한 장이다.
  static const alreadyReserved = '이미 이 공연의 티켓을 가지고 있어요. 한 공연에 한 장만 살 수 있어요.';

  /// 예매 중인 공연이 아닐 때(409). 오픈 전·매진·종료·취소가 전부 여기로 온다.
  static const concertNotOnSale = '지금은 예매할 수 있는 공연이 아니에요.';

  /// 완료 화면이 발행 진행 상태를 다시 묻는 주기. 서버가 체인 트랜잭션 두 개(잔액
  /// 차감 · 발행)의 확정을 기다리는 데 몇 초 걸려, 더 잦게 물으면 서버만 두드린다.
  static const issuePollInterval = Duration(seconds: 3);

  /// 발행 상태 묻기를 그만두는 시점. 이 뒤에도 안 끝났으면 "발행 중" 그대로 두고
  /// 더 묻지 않는다. 서버가 실패 시 주문을 되돌리는 데도 시간이 걸려, 너무 일찍
  /// 그만두면 실패를 못 보여 준다.
  static const issuePollTimeout = Duration(minutes: 2);

  /// 발행 연출 클립(`assets/videos/issuing.mp4`)의 비율. 자산이 1280x720 이다.
  static const issuingClipAspectRatio = 16 / 9;

  /// 클립에서 티켓을 쓰는 구간이 끝나는 지점. 여기까지만 되풀이한다. 이 뒤는 다
  /// 쓴 티켓을 내미는 장면이라 발행이 아직인데 틀면 다 됐다는 꼴이 된다. 클립을
  /// 갈아 끼우면 이 값도 다시 잡는다.
  static const issuingClipLoopEnd = Duration(seconds: 3, milliseconds: 400);

  static const completeTitle = '결제가 완료됐어요';

  /// 발행이 엎어졌을 때의 제목. '결제가 완료됐어요' 를 그대로 두면 바로 아래 환불
  /// 안내와 부딪힌다.
  static const issueFailedTitle = '티켓을 발행하지 못했어요';

  /// 발행을 기다리는 동안 띄우는 연출의 문구. 결제는 이미 끝났고 기다리는 것은
  /// 발행이라 완료 화면의 제목과 다른 말을 쓴다.
  static const issuingCeremonyTitle = '티켓을 발행하고 있어요';
  static const issuingCeremonySemantics = '티켓을 발행하고 있어요. 잠시만 기다려 주세요.';

  /// 기다림이 길어졌을 때 연출의 안내를 바꾸는 시점. 서버가 진행률을 알려 주지
  /// 않으므로 차오르는 막대 대신 시간이 꽤 흘렀다는 사실만 말한다.
  static const issuingHintDelay = Duration(seconds: 40);
  static const issuingDescriptionLong = '조금만 더 기다려 주세요.\n거의 다 왔어요.';

  /// 연출의 진행 바 폭. 화면 끝까지 늘이지 않는 이유는 눈이 가는 곳 때문이다 —
  /// 클립과 문구가 가운데 모여 있는데 막대만 양끝까지 뻗으면 따로 논다.
  static const issuingProgressWidth = 180.0;
  static const issuingProgressHeight = 6.0;

  // 발행 진행 상태 배지와 그 아래 안내. 시안에는 '발행 중' 하나만 있다. 완료와
  // 실패는 같은 자리에 같은 모양으로, 색과 문구만 바꿔 보여 준다.
  static const issuingBadgeLabel = '티켓 발행 중';
  static const issuedBadgeLabel = '티켓 발행 완료';
  static const issueFailedBadgeLabel = '티켓 발행 실패';

  /// 알림을 약속하지 않는다. 백엔드 `NotificationType` 에 발행 완료를 알리는
  /// 종류가 없어 '알림으로 알려드릴게요' 는 지키지 못할 말이다. 결과는 이 화면의
  /// 되묻기가 알린다.
  static const issuingDescription =
      '티켓 발행에는 1~2분이 걸릴 수 있어요.\n끝나면 이 화면에서 알려드릴게요.';
  static const issuedDescription = '티켓이 발행됐어요.\n내 티켓에서 바로 확인할 수 있어요.';

  /// 잔액 차감이나 발행이 실패한 경우다. 서버가 차감했던 금액을 되돌리고 주문을
  /// 취소한다. 실패 사유는 서버 내부 문구라 여기 찍지 않는다.
  static const issueFailedDescription = '티켓 발행에 실패했어요.\n결제된 금액은 자동으로 환불돼요.';

  // [issuePollTimeout] 이 지나도 발행이 안 끝났을 때. 실패가 아니라 지연이므로
  // 실패 화면으로 넘기지 않고, 연출은 그대로 두고 문구와 진행 바 색만 바꾼다.
  static const issueDelayedTitle = '발행이 조금 더 걸리고 있어요';
  static const issueDelayedDescription =
      '발행은 계속 진행 중이에요.\n내 티켓에서 이어서 확인할 수 있어요.';
  static const issueDelayedSemantics =
      '발행이 조금 더 걸리고 있어요. 내 티켓에서 이어서 확인할 수 있어요.';

  /// 결과 화면 맨 위 마스코트의 크기. 원형 포스터(132)보다 조금 크게 잡는다 —
  /// 마스코트는 모자와 꼬리까지 들어 있어 같은 값이면 얼굴이 더 작아 보인다.
  static const resultMascotSize = 150.0;

  static const viewTicketLabel = '티켓 보러 가기';
  static const goHomeLabel = '홈으로';

  static const bookerLabel = '예매자 성함';
  static const ticketPriceLabel = '티켓 가격';
  static const totalLabel = 'TOTAL';
  static const concertLabel = '공연명';
  static const performedAtLabel = '일시';
  static const seatLabel = '좌석';
  static const paidAmountLabel = '결제 금액';

  /// 발행이 엎어져 서버가 돈을 되돌리는 중일 때의 금액 라벨. '결제 금액' 을 두면
  /// 바로 위의 환불 안내와 정반대로 읽힌다. 낸 돈을 가리키는 색인 코랄
  /// ([PaymentColors.total])도 함께 뺀다.
  static const refundAmountLabel = '환불 예정 금액';

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

/// 결제 화면 디자인에 쓰는 색. 다른 화면도 쓰게 되면 `AppTheme` 으로 승격한다.
class PaymentColors {
  PaymentColors._();

  static const page = Color(0xFFF4F5F6);
  static const card = Colors.white;
  static const divider = Color(0xFFEFF0F1);
  static const cardShadow = Color(0x0F000000);

  static const label = Color(0xFF8C9196);
  static const value = Color(0xFF1F2124);

  /// 티켓 가격·수수료 강조색. 브랜드 그린을 그대로 쓴다. 개별 항목(초록)과 최종
  /// 결제 금액(코랄)을 색으로 구분하기로 정한 것이라 시안과 다르다.
  static const price = AppTheme.seedColor;

  /// 최종 결제 금액 강조색.
  static const total = AppTheme.accentColor;
  static const warning = AppTheme.accentColor;

  static const posterPlaceholder = Color(0xFFE7E9EB);
  static const avatarRing = AppTheme.accentColor;

  // 발행 상태 배지. 옅은 바탕에 진한 글자로, 세 상태가 같은 결이다. 글자가 작아
  // 브랜드 초록·코랄을 그대로 쓰면 대비가 모자라 한 단계 진하게 잡았다.
  static const issuingBadgeBackground = Color(0xFFFDF2D0);
  static const issuingBadgeForeground = Color(0xFFB07B12);

  /// 지연된 연출의 진행 바 색. 발행 중 배지와 같은 앰버를 쓴다. 빨강을 쓰면 실패
  /// 화면과 같은 색이 되어 발행이 엎어진 것으로 읽힌다.
  static const delayedProgress = issuingBadgeForeground;
  static const issuedBadgeBackground = Color(0xFFDDF3E7);
  static const issuedBadgeForeground = Color(0xFF0F7A47);
  static const issueFailedBadgeBackground = Color(0xFFFCE4E1);
  static const issueFailedBadgeForeground = Color(0xFFC0392B);
}
