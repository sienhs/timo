import 'package:flutter_test/flutter_test.dart';

import 'package:timo/app.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/notification/notification_destination.dart';
import 'package:timo/features/notification/push_notification_service.dart';
import 'package:timo/routes/app_routes.dart';

/// 앱이 뜨면서 이 기기를 푸시 대상으로 등록하는지. 인증 헤더 인터셉터는 앱 위젯이
/// 뜨면서 꽂히므로 푸시 서비스가 시작하며 혼자 등록하면 401 로 튕긴다 — 그래서
/// 등록은 앱이 부른다. 저장된 로그인으로 앱을 다시 켠 경우에만 생기는 구멍이다.
void main() {
  Future<_RecordingPush> pumpApp(
    WidgetTester tester, {
    bool registrationFails = false,
  }) async {
    final push = _RecordingPush(fails: registrationFails);
    final session = AuthSession(storage: InMemoryTokenStorage());
    await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      App(
        // 볼 것은 앱이 뜨는 순간의 등록뿐이다. 홈은 배너 타이머 때문에 테스트가
        // 끝나지 않으므로 타이머가 없는 화면으로 띄운다.
        initialRoute: AppRoutes.login,
        session: session,
        push: push,
        authApi: MockAuthApi(latency: Duration.zero),
      ),
    );
    // 앱이 뜨면서 건 짧은 작업들이 끝나게 둔다. 안 그러면 테스트가 "아직 도는
    // 타이머가 있다" 며 실패한다.
    await tester.pump(const Duration(milliseconds: 1));
    return push;
  }

  testWidgets('앱이 뜨면 기기를 등록한다', (tester) async {
    final push = await pumpApp(tester);

    expect(push.registerCalls, 1);
  });

  testWidgets('등록이 실패해도 앱은 그대로 뜬다', (tester) async {
    // 네트워크가 끊겨 있을 수 있다. 등록은 화면을 막을 일이 아니다.
    final push = await pumpApp(tester, registrationFails: true);

    expect(push.registerCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

/// 기기 등록이 불렸는지 세는 가짜. 진짜 구현은 만들 때 Firebase 를 건드려
/// 테스트에서 못 만든다.
class _RecordingPush implements PushNotifications {
  _RecordingPush({this.fails = false});

  final bool fails;
  int registerCalls = 0;

  @override
  Future<void> registerDevice() async {
    registerCalls++;
    if (fails) throw Exception('등록 실패');
  }

  @override
  Future<void> unregisterDevice() async {}

  @override
  NotificationDestination? takeLaunchDestination() => null;

  @override
  Stream<int> get unreadCounts => const Stream.empty();
}
