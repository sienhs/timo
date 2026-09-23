import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/network/api_client.dart';
import '../auth/state/auth_session.dart';
import 'notification_destination.dart';

/// 이 기기를 푸시 수신 대상에서 빼는 일만 떼어낸 약속.
///
/// 로그아웃 화면이 필요한 건 이 한 가지뿐이다.
abstract class PushDeviceRegistrar {
  /// 서버에서 이 기기의 푸시 토큰을 지운다. 실패해도 예외를 던지지 않는다.
  Future<void> unregisterDevice();
}

/// 앱 화면이 푸시 쪽에 부탁하는 것들. 구현체([PushNotificationService])는 만들 때
/// Firebase 를 건드려 화면 테스트에서 만들 수 없으므로, 화면이 쓰는 것만 약속으로
/// 떼어 내려주고 테스트는 가짜를 넣는다.
abstract class PushNotifications implements PushDeviceRegistrar {
  /// 알림을 눌러 앱이 켜진 것이라면 그 알림이 가리키는 화면. 아니면 null.
  /// 한 번 가져가면 없어진다 — 로딩 화면이 홈으로 넘긴 직후 한 번만 묻는다.
  NotificationDestination? takeLaunchDestination();

  /// 로그인 상태면 이 기기를 서버에 등록한다. 로그아웃 상태면 아무것도 안 한다.
  /// 인증 헤더를 붙이는 인터셉터가 꽂힌 뒤에 불러야 한다 — 서비스 시작 때 혼자
  /// 등록하면 헤더 없이 나가 401 이고 재시도도 안 된다. 로그인 때는 세션이 바뀌며
  /// 저절로 등록되므로, 저장된 로그인으로 앱을 다시 켠 경우에만 필요하다.
  Future<void> registerDevice();

  /// 앱이 켜져 있을 때 푸시가 오면, 서버가 같이 실어 보낸 안 읽은 알림 개수. 종 위의
  /// 점이 이걸 듣고 바로 바뀐다. 값이 같아도 매번 흘려보낸다 — 알림함에서 읽고
  /// 돌아와 점이 꺼진 뒤 같은 개수가 와도 켜져야 한다(`ValueNotifier` 로는 안 된다).
  /// 앱이 뒤에 있을 때 온 푸시는 여기 오지 않고, 화면에 다시 들어올 때 묻는 개수가 맞춘다.
  Stream<int> get unreadCounts;
}

/// 아무것도 하지 않는 구현. Firebase 를 띄우지 않는 실행(위젯 테스트 등)에서
/// 스코프를 비워 두지 않으려고 쓴다.
class NoopPushNotifications implements PushNotifications {
  const NoopPushNotifications();

  @override
  Future<void> unregisterDevice() async {}

  @override
  NotificationDestination? takeLaunchDestination() => null;

  @override
  Future<void> registerDevice() async {}

  @override
  Stream<int> get unreadCounts => const Stream.empty();
}

/// FCM 권한, 토큰 등록·해제, 앱이 열린 상태의 배너, 알림을 눌렀을 때의 화면 이동을
/// 한곳에서 관리한다. 어느 화면으로 갈지는 [destinationFor] 가 정하고 이 서비스는
/// 알림 종류를 모른다.
class PushNotificationService implements PushNotifications {
  PushNotificationService(
    this._session, {
    this.navigatorKey,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    Dio? dio,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _dio = dio ?? ApiClient.dio;

  static const _devicePath = '/api/v1/notifications/devices';

  /// 안드로이드 알림 채널. **채널을 만들 때와 알림을 띄울 때 같은 값이어야 한다.**
  /// 없는 채널로 띄우면 안드로이드 8.0 이상에서는 알림이 아예 표시되지 않고 예외도
  /// 로그도 남지 않는다. 그래서 문자열을 양쪽에 따로 적지 않고 여기 한 벌만 둔다.
  static const _channelId = 'timo_general_notifications';
  static const _channelName = '일반 알림';
  static const _channelDescription = '예매, 티켓, 공연 관련 알림입니다.';

  static const _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
  );

  /// 알림을 눌렀을 때 화면을 바꾸는 데 쓴다. 앱 시작 지점이 앱과 같은 것을 준다.
  /// 없으면(테스트) 이동만 하지 않는다.
  final GlobalKey<NavigatorState>? navigatorKey;

  final AuthSession _session;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Dio _dio;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  final StreamController<int> _unreadCounts = StreamController.broadcast();
  String? _token;
  bool _started = false;

  /// 알림을 눌러 앱이 켜졌을 때 그 알림이 가리키던 화면.
  /// [takeLaunchDestination] 이 가져가면 비워진다.
  NotificationDestination? _launchDestination;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _initializeLocalNotifications();
    await _messaging.requestPermission();
    _token = await _messaging.getToken();
    // 여기서 등록하지 않는다. 인증 헤더 인터셉터가 아직 안 꽂혀 401 로 튕긴다.
    // 앱이 준비를 마친 뒤 [registerDevice] 로 부른다.

    // 앱이 꺼져 있을 때 온 알림을 눌러 켠 경우. 지금 화면을 바꾸면 로딩 화면이 홈으로
    // 갈아치우며 사라지므로, 들고 있다가 [takeLaunchDestination] 때 넘긴다.
    final launchMessage = await _messaging.getInitialMessage();
    if (launchMessage != null) {
      _launchDestination = destinationForPushData(launchMessage.data);
    }

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      _token = token;
      unawaited(_registerCurrentToken());
    });
    _session.addListener(_onSessionChanged);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final unread = unreadCountOf(message.data);
      if (unread != null) _unreadCounts.add(unread);
      _showForegroundNotification(message);
    });
    // 앱이 뒤에 떠 있을 때 트레이의 알림을 누른 경우. 화면이 이미 있어 바로 옮긴다.
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _goTo(destinationForPushData(message.data)),
    );
  }

  @override
  Stream<int> get unreadCounts => _unreadCounts.stream;

  /// 푸시 `data` 의 안 읽은 알림 개수. 푸시 `data` 는 값이 전부 문자열이라 숫자로
  /// 바꾼다. 없거나 숫자가 아니면 null 이고, 그때는 점을 건드리지 않는다.
  @visibleForTesting
  static int? unreadCountOf(Map<String, dynamic> data) {
    final raw = data['unreadCount'];
    final parsed = raw is String ? int.tryParse(raw) : null;
    return parsed == null || parsed < 0 ? null : parsed;
  }

  @override
  NotificationDestination? takeLaunchDestination() {
    final destination = _launchDestination;
    _launchDestination = null;
    return destination;
  }

  /// 앱이 인증 헤더를 붙일 준비를 마친 뒤 부른다. [start] 는 토큰만 받아 두고
  /// 등록은 여기까지 미룬다.
  @override
  Future<void> registerDevice() => _registerCurrentToken();

  /// 알림이 가리키는 화면을 연다. 갈 곳이 없으면 아무것도 하지 않는다. 홈을
  /// 갈아치우지 않고 위에 쌓아, 뒤로가기로 홈에 돌아갈 수 있게 한다.
  void _goTo(NotificationDestination? destination) {
    if (destination == null) return;
    navigatorKey?.currentState?.pushNamed(
      destination.routeName,
      arguments: destination.arguments,
    );
  }

  /// 앱이 켜져 있을 때 뜬 배너를 누른 경우. 직접 띄운 알림이라 이동 정보도
  /// 우리가 [_showForegroundNotification] 에서 실어 둔 것을 되읽는다.
  void _onBannerTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) _goTo(destinationForPushData(data));
    } on FormatException catch (error) {
      // 우리가 실은 값이라 깨질 일은 없지만, 깨졌다고 앱이 죽을 이유도 없다.
      debugPrint('Push payload parse failed: $error');
    }
  }

  /// 로그인하면 이 기기를 등록하고, 로그아웃하면 기기 토큰을 버린다. 버리는 쪽은
  /// [unregisterDevice] 를 못 부르거나(리프레시 토큰 만료) 실패한 로그아웃의 뒷문이다.
  /// 안 버리면 서버에 이 토큰이 직전 회원 것으로 남아 알림이 계속 온다.
  void _onSessionChanged() {
    if (_session.isLoggedIn) {
      unawaited(_registerCurrentToken());
    } else {
      unawaited(_discardToken());
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onBannerTapped,
    );
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_channel);
  }

  Future<void> _registerCurrentToken() async {
    final token = _token;
    if (token == null || !_session.isLoggedIn) return;
    try {
      await _dio.put<void>(
        _devicePath,
        data: {'token': token, 'platform': defaultTargetPlatform.name},
      );
    } on DioException catch (error) {
      // 푸시 등록 실패가 로그인·예매 흐름을 막으면 안 된다. 다음 토큰 갱신이나
      // 앱 재실행에서 재시도한다. 토큰 원문은 개인정보 식별자라 로그에 남기지 않는다.
      debugPrint(
        'Push token registration failed: ${error.response?.statusCode}',
      );
    }
  }

  /// 서버에서 이 기기의 푸시 토큰을 지운다. 로그아웃할 때 부른다.
  /// 반드시 세션을 비우기 전에 불러야 한다 — 서버가 인증 헤더로 누군지 알아내므로
  /// 세션을 먼저 비우면 401 로 튕기고 토큰이 남아 직전 회원의 알림이 계속 온다.
  /// 기기의 FCM 토큰 자체는 두어, 다시 로그인하면 같은 토큰이 새 회원으로 등록된다.
  @override
  Future<void> unregisterDevice() async {
    final token = _token;
    if (token == null || !_session.isLoggedIn) return;
    try {
      await _dio.delete<void>(_devicePath, data: {'token': token});
    } on DioException catch (error) {
      // 서버에 못 알린 것뿐이라 로그아웃은 그대로 진행한다. 로그아웃을 되돌릴
      // 수도, 사용자가 할 수 있는 일도 없다. 서버 로그아웃 알림과 같은 정책이다.
      debugPrint(
        'Push token unregistration failed: ${error.response?.statusCode}',
      );
    }
  }

  /// 이 기기의 FCM 토큰 자체를 버린다. 서버에 해제를 알리지 못한 채 로그아웃한
  /// 경우의 뒷문이다 — 버린 토큰으로 온 발송은 FCM 이 "없는 토큰" 으로 답해 서버가
  /// 자기 기록을 지운다. FCM 이 곧 새 토큰을 내주고 [start] 의 구독이 갈아끼운다.
  Future<void> _discardToken() async {
    try {
      await _messaging.deleteToken();
      _token = null;
    } on Exception catch (error) {
      // 못 버렸으면 서버에는 토큰이 남는다. 다음 로그인 때 그 회원으로 다시
      // 등록되며 덮인다. 로그아웃을 막을 일은 아니다.
      debugPrint('Push token discard failed: $error');
    }
  }

  /// 앱이 켜져 있을 때는 시스템이 알림을 그려 주지 않아 우리가 배너를 띄운다.
  /// 이동 정보는 payload 에 실어 두고 [_onBannerTapped] 가 되읽는다. 본문은 펼침으로
  /// 띄운다 — 양도 매물 알림은 네 줄까지 오는데 그냥 띄우면 첫 줄만 보인다.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final body = notification.body;
    await _localNotifications.show(
      _bannerId(message, notification),
      notification.title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: body == null ? null : BigTextStyleInformation(body),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// 배너를 구분하는 번호. 알림함의 알림 번호를 그대로 써서 같은 알림은 하나로
  /// 합치고 다른 알림은 따로 쌓는다. 번호가 없으면 내용으로 대신한다. 안드로이드
  /// 알림 번호는 32비트라 아래 비트만 남긴다.
  static int _bannerId(RemoteMessage message, RemoteNotification notification) {
    final raw = message.data['notificationId'];
    final parsed = raw is String ? int.tryParse(raw) : null;
    return (parsed ?? notification.hashCode) & 0x7FFFFFFF;
  }

  Future<void> dispose() async {
    _session.removeListener(_onSessionChanged);
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    await _unreadCounts.close();
  }
}
