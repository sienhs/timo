import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/auth/data/device_id.dart';
import 'features/auth/data/token_storage.dart';
import 'features/auth/state/auth_session.dart';
import 'features/favorite/data/favorite_artist_store.dart';
import 'features/home/data/recent_search_store.dart';
import 'features/memory/data/ticket_store.dart';
import 'features/memory/data/tilt_setting.dart';
import 'features/memory/data/viewer_guide_setting.dart';
import 'features/notification/push_notification_service.dart';

/// 백그라운드 수신은 Flutter 엔진이 이 진입점을 찾아 호출하므로 트리 셰이킹하면 안 된다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  // 기기 저장소(플러그인)를 runApp 전에 쓰려면 먼저 엔진과 연결해야 한다.
  WidgetsFlutterBinding.ensureInitialized();

  // 세로로만 쓴다. 가로로 돌리면 좌석 배치도·티켓처럼 세로를 전제로 짠 화면이
  // 무너진다. 안드로이드 매니페스트에도 같은 값을 박아 두는데, 그쪽은 플러터가
  // 뜨기 전(런치 화면)까지 막아 준다.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final storage = SecureTokenStorage();
  final session = AuthSession(storage: storage);
  // 첫 화면부터 로그인 여부가 맞아야 하므로 띄우기 전에 되살린다. 수십 ms 다.
  // 저장소를 읽지 못하는 상황(키스토어 오류 등)이면 로그아웃 상태로 시작한다.
  // 앱이 안 켜지는 것보다 다시 로그인하게 하는 쪽이 낫다.
  try {
    await DeviceId.restore(storage);
    await session.restore();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'timo auth',
        context: ErrorDescription('기기 저장소에서 로그인 정보를 되살리는 중'),
      ),
    );
  }

  // 권한·토큰은 기기 단위, 서버 등록은 로그인 회원 단위다. 로그인/로그아웃을
  // 구독하므로 앱을 켠 뒤 로그인해도, FCM 토큰이 바뀌어도 자동으로 동기화된다.
  // 알림을 눌렀을 때 푸시 쪽도 화면을 바꿔야 한다. 앱이 혼자 만들면 푸시가 그
  // 열쇠에 닿을 수 없어, 여기서 하나 만들어 앱과 푸시 양쪽에 같은 것을 준다.
  final navigatorKey = GlobalKey<NavigatorState>();

  final pushNotificationService = PushNotificationService(
    session,
    navigatorKey: navigatorKey,
  );
  // 푸시 준비가 실패해도 앱은 켠다. FCM 토큰 발급은 네트워크가 없으면 예외를
  // 던지는데(`FCM Registration failed`), 여기서 그대로 두면 runApp 에 닿지 못해
  // 앱이 스플래시에서 멈춘다 — 오프라인으로 켠 사람이 소장품 하나 못 본다.
  // 토큰은 나중에 갱신 스트림으로 들어오고, 등록은 그때 다시 시도한다.
  try {
    await pushNotificationService.start();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'timo push',
        context: ErrorDescription('푸시 알림을 준비하는 중'),
      ),
    );
  }

  // 소장품(메모리 티켓) 저장소. 컬렉션 화면이 열리자마자 목록을 그려야 해서
  // 상자를 여기서 미리 연다. 여는 데 실패하면 소장품 기능만 빼고 앱은 켠다 —
  // 예매·티켓은 이 상자와 아무 상관이 없다.
  TicketStore? ticketStore;
  try {
    await Hive.initFlutter();
    ticketStore = HiveTicketStore(
      await Hive.openBox<String>(HiveTicketStore.boxName),
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'timo memory',
        context: ErrorDescription('소장품 저장소를 여는 중'),
      ),
    );
  }

  runApp(
    App(
      session: session,
      // 최근 검색어는 검색 화면이 열릴 때 읽으므로 여기서 기다리지 않는다.
      recentSearchStore: SharedPreferencesRecentSearchStore(),
      // 찜한 공연은 서버에 있다. 기기에 남는 것은 아티스트뿐이고, 그 목록은
      // App 이 켜지면서 읽는다 — 여기서 기다릴 만큼 급하지 않다.
      favoriteArtistStore: SharedPreferencesFavoriteArtistStore(),
      ticketStore: ticketStore,
      // 기울임 효과를 껐는지도 기기에 남는다. App 이 켜지면서 읽는다.
      tiltSettingStore: SharedPreferencesTiltSettingStore(),
      // 소장품 조작법 안내를 봤는지도 기기에 남는다.
      viewerGuideStore: SharedPreferencesViewerGuideStore(),
      // 로그아웃할 때 이 기기의 푸시 토큰을 서버에서 지우려면 화면이 이 서비스에
      // 닿아야 한다. 등록은 서비스가 세션을 구독해 알아서 하지만, 해제는 세션을
      // 비우기 전에 일어나야 해서 로그아웃하는 쪽이 직접 불러야 한다. 로딩 화면도
      // 알림으로 켜진 것인지 여기에 묻는다.
      push: pushNotificationService,
      navigatorKey: navigatorKey,
    ),
  );
}
