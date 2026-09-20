import 'package:flutter/material.dart';

import '../features/auth/models/signup_draft.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_complete_screen.dart';
import '../features/auth/screens/wallet_creating_screen.dart';
import '../features/auth/screens/signup_account_screen.dart';
import '../features/auth/screens/signup_nickname_screen.dart';
import '../features/auth/screens/signup_phone_screen.dart';
import '../features/booking/constants.dart';
import '../features/booking/screens/seat_selection_screen.dart';
import '../features/booking/screens/zone_selection_screen.dart';
import '../features/booking/state/booking_scope.dart';
import '../features/booking/state/ticket_order_adapter.dart';
import '../features/favorite/screens/favorite_list_screen.dart';
import '../features/home/screens/show_search_screen.dart';
import '../features/memory/screens/collection_screen.dart';
import '../features/mypage/screens/coin_charge_screen.dart';
import '../features/shell/screens/main_shell_screen.dart';
import '../features/ticket/models/my_ticket.dart';
import '../features/ticket/screens/entry_qr_screen.dart';
import '../features/ticket/screens/my_tickets_screen.dart';
import '../features/show/screens/show_detail_screen.dart';
import '../features/payment/models/order_target.dart';
import '../features/payment/models/placed_order.dart';
import '../features/payment/screens/payment_complete_screen.dart';
import '../features/payment/screens/payment_screen.dart';
import '../features/resale/models/market_concert.dart';
import '../features/resale/models/purchased_trade.dart';
import '../features/notification/screens/notification_screen.dart';
import '../features/resale/screens/listing_purchase_complete_screen.dart';
import '../features/resale/screens/listing_purchase_screen.dart';
import '../features/resale/screens/listing_register_screen.dart';
import '../features/resale/screens/market_concerts_screen.dart';
import '../features/resale/screens/market_listings_screen.dart';
import '../features/splash/screens/splash_screen.dart';

/// 화면 라우트 등록부.
/// 새 화면을 만들면 1) 이름 상수 추가, 2) routes 맵에 builder 등록.
/// 이동은 Navigator.pushNamed(context, AppRoutes.xxx) 사용.
class AppRoutes {
  AppRoutes._();

  /// 로딩(스플래시). 앱의 첫 화면이다. 애니메이션이 끝나면 홈으로 교체 이동해
  /// 뒤로 가기로 돌아올 수 없다. 첫 화면인데 이름이 '/' 가 아닌 사정은 App 의
  /// 첫 화면 처리 주석에 있다.
  static const splash = '/splash';

  /// 홈. 로딩이 끝나면 여기로 오고, 다른 화면들이 "홈으로" 갈 때도 이 이름을
  /// 쓴다.
  static const home = '/';

  /// 공연 상세. 공연 id 를 arguments 로 받는다.
  static const showDetail = '/show';

  /// 공연 검색. 홈 상단 검색 바에서 들어온다. 찜리스트의 아티스트처럼 검색어를
  /// 정해 두고 열 때는 그 말을 arguments 로 넘긴다.
  static const showSearch = '/search';

  /// 찜리스트. 빠른 메뉴에서 들어온다.
  static const favorites = '/favorites';

  /// 내 티켓. 빠른 메뉴에서 들어온다.
  static const myTickets = '/tickets';

  /// 알림함. 마이페이지 상단의 알림 아이콘에서 들어온다.
  static const notifications = '/notifications';

  /// 버섯 충전. 마이페이지의 충전하기와 빠른 메뉴에서 들어온다. 충전에
  /// 성공하면 결과로 true 를 넘기며 이전 화면으로 돌아간다.
  static const coinCharge = '/mypage/charge';

  /// 입장 QR. 내 티켓의 예정 공연 카드에서 티켓([MyTicket])을 받아 연다.
  static const entryQr = '/tickets/qr';

  /// 소장품(메모리 티켓) 컬렉션. 빠른 메뉴에서 들어온다. 제작·뷰어는 이
  /// 화면에서 이어지는 흐름이라 라우트로 따로 내놓지 않는다.
  static const collection = '/collection';

  /// 구역 배치도(좌석 선택 시작)
  static const zoneSelection = '/booking/zones';

  /// 구역 하나의 좌석 배치도. 구역 id 를 arguments 로 받는다.
  static const seatSelection = '/booking/seats';

  static const payment = '/payment';
  static const paymentComplete = '/payment/complete';

  /// 양도마켓. 빠른 메뉴에서 들어온다. 마켓이 닫혀 있으면 같은 라우트가
  /// 다음 오픈까지 남은 시간을 보여 준다 — 닫힘은 다른 화면이 아니라 이
  /// 화면의 한 상태다.
  static const resaleMarket = '/resale';

  /// 공연 하나의 매물 목록. 고른 공연([MarketConcert])을 arguments 로 받는다.
  static const resaleListings = '/resale/listings';

  /// 양도 티켓 구매 확인. 매물 번호를 arguments 로 받는다.
  static const resalePurchase = '/resale/purchase';

  /// 양도 결제 완료. 체결 결과와 포스터([PurchaseResult])를 arguments 로 받는다.
  static const resalePurchaseComplete = '/resale/purchase/complete';

  /// 양도 등록. 등록에 성공하면 결과로 true 를 넘기며 이전 화면으로 돌아간다.
  static const resaleRegister = '/resale/register';

  /// 로그인. 성공하면 결과로 true 를 넘기며 이전 화면으로 돌아간다.
  static const login = '/login';

  /// 회원가입. 단계 화면은 앞 단계까지 채운 SignupDraft 를 arguments 로 받는다.
  static const signupPhone = '/signup/phone';

  /// 아이디와 비밀번호를 한 화면에서 받는다. 예전에는 따로였다.
  static const signupAccount = '/signup/account';
  static const signupNickname = '/signup/nickname';
  /// 가입 직후 지갑을 준비하는 연출. 영상이 끝나면 스스로 완료 화면으로 바뀐다.
  static const signupWallet = '/signup/wallet';
  static const signupComplete = '/signup/complete';

  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    // 홈은 하단 바를 두른 셸이다. 탭 본문(홈·마이페이지)은 셸이 들고 있어
    // 라우트로 노출하지 않는다. 빠른 메뉴에서 연 화면이 하단 바로 돌아올 때는
    // 열 탭 번호를 arguments 로 넘긴다.
    home: (context) => MainShellScreen(
      initialTab: ModalRoute.of(context)!.settings.arguments as int? ?? 0,
    ),
    // 목록에서는 공연 번호만 넘어온다. 조회는 화면이 직접 한다.
    showDetail: (context) => ShowDetailScreen(showId: _showIdArg(context)),
    showSearch: (context) => ShowSearchScreen(
      initialKeyword: ModalRoute.of(context)!.settings.arguments as String?,
    ),
    favorites: (_) => const FavoriteListScreen(),
    myTickets: (_) => const MyTicketsScreen(),
    coinCharge: (_) => const CoinChargeScreen(),
    notifications: (_) => const NotificationScreen(),
    collection: (_) => const CollectionScreen(),
    // 목록이 이미 들고 있는 티켓을 그대로 넘긴다. id 만 넘겨 여기서 다시
    // 조회하면 입장 직전에 네트워크를 한 번 더 타게 된다.
    entryQr: (context) => EntryQrScreen(
      ticket: ModalRoute.of(context)!.settings.arguments! as MyTicket,
    ),
    // 예매 흐름 밖에서 열리면(딥링크·화면 단위 테스트) 공연 번호가 없다.
    // 그때만 기본 공연으로 대신한다.
    zoneSelection: (context) => ZoneSelectionScreen(
      concertId:
          ModalRoute.of(context)!.settings.arguments as int? ??
          BookingConstants.fallbackConcertId,
    ),
    // 인자를 받는 화면은 여기서 한 번만 꺼내 타입을 맞춘다. 화면 위젯이
    // ModalRoute 를 직접 뒤지지 않게 해서 단독 테스트가 가능하다.
    seatSelection: (context) => SeatSelectionScreen(
      zoneId: ModalRoute.of(context)!.settings.arguments! as int,
    ),
    // 고른 좌석으로 주문을 만들어 넘긴다. 이 연결이 없으면 어떤 좌석을 골라도
    // 결제 화면에 더미 좌석(A구역 9열 6번)이 찍힌다. 예매 흐름을 거치지 않고
    // 열린 경우는 ticketOrderOrSample 이 더미로 대체한다.
    payment: (context) {
      final booking = BookingScope.maybeRead(context);
      final hold = booking?.hold;
      return PaymentScreen(
        order: ticketOrderOrSample(context),
        // 잡아 둔 자리가 풀리기까지 남은 시간. 예매 흐름 밖에서 열렸으면 잡아 둔
        // 자리가 없어 null 이고, 화면이 규약값(5분)으로 센다.
        holdRemaining: hold?.remainingFrom(DateTime.now()),
        // 잡아 둔 자리가 있을 때만 서버에 주문을 만든다. 없으면(예매 흐름 밖)
        // 결제하기는 완료 화면만 보여 준다.
        target: booking == null || hold == null
            ? null
            : OrderTarget(concertId: booking.concertId, seatId: hold.seatId),
      );
    },
    // 결제 화면이 주문 정보와 예매 번호를 인자로 넘긴다. 인자 없이 열리면
    // (딥링크 · 화면 단위 테스트) 예매 흐름의 주문이나 더미로 대신하고, 서버에
    // 만든 주문이 없으니 발행 상태는 묻지 않는다.
    paymentComplete: (context) {
      final placed = ModalRoute.of(context)!.settings.arguments as PlacedOrder?;
      return PaymentCompleteScreen(
        order: placed?.order ?? ticketOrderOrSample(context),
        reservationId: placed?.reservationId,
      );
    },
    resaleMarket: (_) => const MarketConcertsScreen(),
    // 매물 목록은 고른 공연을 통째로 받는다. 매물 응답에 공연 정보가 없어
    // 제목과 회차를 그 값에서 가져온다.
    resaleListings: (context) => MarketListingsScreen(
      concert: ModalRoute.of(context)!.settings.arguments! as MarketConcert,
    ),
    resalePurchase: (context) => ListingPurchaseScreen(
      listingId: ModalRoute.of(context)!.settings.arguments! as int,
    ),
    resalePurchaseComplete: (context) => ListingPurchaseCompleteScreen(
      result: ModalRoute.of(context)!.settings.arguments! as PurchaseResult,
    ),
    // 내 티켓 카드에서 들어오면 그 티켓 번호를 받아 미리 골라 둔다. 마켓 첫
    // 화면의 버튼으로 들어오면 인자가 없다.
    resaleRegister: (context) => ListingRegisterScreen(
      initialTicketId: ModalRoute.of(context)?.settings.arguments as int?,
    ),
    login: (_) => const LoginScreen(),
    signupPhone: (_) => const SignupPhoneScreen(),
    signupAccount: (context) =>
        SignupAccountScreen(draft: _signupDraft(context)),
    signupNickname: (context) =>
        SignupNicknameScreen(draft: _signupDraft(context)),
    signupWallet: (_) => const WalletCreatingScreen(),
    signupComplete: (_) => const SignupCompleteScreen(),
  };

  /// 공연 상세가 받는 라우트 인자. 서버가 준 공연 번호다.
  ///
  /// 번호 없이 열리면(딥링크, 화면 단위 실행) 기본 공연으로 대신한다. 예매
  /// 흐름이 [BookingConstants.fallbackConcertId] 로 하는 것과 같다.
  static int _showIdArg(BuildContext context) =>
      ModalRoute.of(context)!.settings.arguments as int? ??
      BookingConstants.fallbackConcertId;

  /// 회원가입 단계 화면이 받는 초안. 초안 없이 열리면(화면 단위 테스트,
  /// 딥링크) 빈 초안으로 시작해 화면이 죽지 않게 한다.
  static SignupDraft _signupDraft(BuildContext context) =>
      ModalRoute.of(context)!.settings.arguments as SignupDraft? ??
      const SignupDraft();
}
