import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/device_storage.dart';
import 'features/auth/data/device_id.dart';
import 'features/auth/state/auth_session.dart';
import 'features/concert/data/selected_concert_storage.dart';
import 'features/concert/models/concert_summary.dart';

Future<void> main() async {
  // 기기 저장소(플러그인)를 runApp 전에 쓰려면 먼저 엔진과 연결해야 한다.
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SecureDeviceStorage();
  final session = AuthSession(storage: storage);
  final concertStorage = SelectedConcertStorage(storage);
  ConcertSummary? concert;
  // 첫 화면이 로그인·공연 선택·스캔 중 무엇인지가 저장된 값에 달려 있어
  // 띄우기 전에 되살린다. 저장소를 읽지 못하는 상황(키스토어 오류 등)이면
  // 로그아웃 상태로 시작한다. 앱이 안 켜지는 것보다 다시 로그인하게 하는 쪽이 낫다.
  try {
    await DeviceId.restore(storage);
    await session.restore();
    concert = await concertStorage.read();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'timo gate',
        context: ErrorDescription('기기 저장소에서 로그인 정보·공연을 되살리는 중'),
      ),
    );
  }

  runApp(
    App(
      session: session,
      concertStorage: concertStorage,
      initialConcert: concert,
    ),
  );
}
