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
  // 무너진다. 안드로이드 매니페스트의 같은 값은 플러터가 뜨기 전까지 막아 준다.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final storage = SecureTokenStorage();
  final session = AuthSession(storage: storage);
  // 첫 화면부터 로그인 여부가 맞아야 하므로 띄우기 전에 되살린다. 저장소를 읽지
  // 못하면(키스토어 오류 등) 앱을 못 켜느니 로그아웃 상태로 시작하는 게 낫다.
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

  // 푸시 등록은 서비스가 세션을 구독해 알아서 맞춘다. 알림을 눌렀을 때 푸시 쪽도
  // 화면을 바꿔야 해서 열쇠를 여기서 하나 만들어 앱과 푸시 양쪽에 같은 것을 준다.
  final navigatorKey = GlobalKey<NavigatorState>();

  final pushNotificationService = PushNotificationService(
    session,
    navigatorKey: navigatorKey,
  );
  // 푸시 준비가 실패해도 앱은 켠다. 오프라인이면 FCM 토큰 발급이 예외를 던지는데
  // 그대로 두면 runApp 에 닿지 못한다. 토큰은 나중에 갱신 스트림으로 들어온다.
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
      // 푸시 해제는 세션을 비우기 전에 일어나야 해서 로그아웃하는 화면이 직접
      // 부른다. 로딩 화면도 알림으로 켜진 것인지 여기에 묻는다.
      push: pushNotificationService,
      navigatorKey: navigatorKey,
    ),
  );
}
