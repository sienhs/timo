import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/auth/data/device_id.dart';
import 'features/auth/data/token_storage.dart';
import 'features/auth/state/auth_session.dart';
import 'features/favorite/data/favorite_store.dart';
import 'features/home/data/recent_search_store.dart';
import 'features/memory/data/ticket_store.dart';

Future<void> main() async {
  // 기기 저장소(플러그인)를 runApp 전에 쓰려면 먼저 엔진과 연결해야 한다.
  WidgetsFlutterBinding.ensureInitialized();

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

  // 찜 목록. 검색 결과의 하트가 첫 화면부터 찜 여부를 맞게 그려야 해서 띄우기
  // 전에 되살린다. 수 ms 다. 읽지 못하면(저장소 오류·깨진 JSON) 빈 목록으로
  // 시작하고, 다음에 하트를 누를 때 덮어쓴다.
  final favoriteStore = SharedPreferencesFavoriteStore();
  try {
    await favoriteStore.restore();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'timo favorite',
        context: ErrorDescription('기기 저장소에서 찜 목록을 되살리는 중'),
      ),
    );
  }

  runApp(
    App(
      session: session,
      // 최근 검색어는 검색 화면이 열릴 때 읽으므로 여기서 기다리지 않는다.
      recentSearchStore: SharedPreferencesRecentSearchStore(),
      favoriteStore: favoriteStore,
      ticketStore: ticketStore,
    ),
  );
}
