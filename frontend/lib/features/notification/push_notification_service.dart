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

/// 앱 화면이 푸시 쪽에 부탁하는 것들.
///
/// 구현체([PushNotificationService])는 만들 때 Firebase 를 건드려서 화면 테스트에서
/// 아예 만들 수가 없다. 그래서 화면이 쓰는 것만 약속으로 떼어 내려주고 테스트는
/// 가짜를 넣는다. `AuthApi` 와 `HttpAuthApi` 의 관계와 같다.
abstract class PushNotifications implements PushDeviceRegistrar {
  /// 알림을 눌러 앱이 켜진 것이라면 그 알림이 가리키는 화면. 아니면 null.
  ///
  /// **한 번 가져가면 없어진다.** 로딩 화면이 홈으로 넘긴 직후 한 번만 묻고,
  /// 그 뒤에 앱을 다시 보게 돼도 같은 화면이 또 열리면 안 된다.
  NotificationDestination? takeLaunchDestination();

  /// 로그인 상태면 이 기기를 서버에 등록한다. 로그아웃 상태면 아무것도 안 한다.
  ///
  /// **앱이 요청에 인증 헤더를 붙일 준비를 마친 뒤에 불러야 한다.** 푸시 서비스는
  /// 앱보다 먼저 시작하는데, 헤더를 붙이는 인터셉터는 앱 위젯이 뜨면서 꽂힌다.
  /// 그래서 서비스가 시작하면서 혼자 등록하면 헤더 없이 나가 401 로 튕기고,
  /// 재발급도 그 인터셉터의 일이라 다시 시도되지 않는다.
  ///
  /// 로그인할 때는 세션이 바뀌면서 저절로 등록되므로 이 호출이 필요 없다. 저장된
  /// 로그인으로 앱을 다시 켠 경우에만 빈자리가 생긴다.
  Future<void> registerDevice();
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
}

/// FCM 권한, 토큰 등록·해제, 앱이 열린 상태의 배너, 알림을 눌렀을 때의 화면 이동을
/// 한곳에서 관리한다.
///
/// 탭이 들어오는 길은 셋이다 — 앱이 켜져 있을 때의 배너, 뒤에 있을 때의 트레이,
/// 꺼져 있을 때 알림으로 켜진 경우. 어느 화면으로 갈지는 [destinationFor] 가 정하고
/// 이 서비스는 알림 종류를 모른다.
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
    // 여기서 등록하지 않는다. 이 서비스는 앱보다 먼저 시작하는데, 요청에 인증
    // 헤더를 붙이는 인터셉터는 앱 위젯이 뜨면서 꽂힌다. 지금 보내면 헤더 없이
    // 나가 401 로 튕기고 재시도도 안 된다. 앱이 준비를 마친 뒤 [registerDevice]
    // 로 부른다.

    // 앱이 꺼져 있을 때 온 알림을 눌러 켠 경우. 여기서 바로 화면을 바꾸면 안 된다 —
    // 로딩 화면이 끝나며 홈으로 갈아치우느라 방금 연 화면이 사라진다. 들고 있다가
    // 로딩 화면이 [takeLaunchDestination] 으로 물어볼 때 넘긴다.
    final launchMessage = await _messaging.getInitialMessage();
    if (launchMessage != null) {
      _launchDestination = destinationForPushData(launchMessage.data);
    }

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      _token = token;
      unawaited(_registerCurrentToken());
    });
    _session.addListener(_onSessionChanged);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    // 앱이 뒤에 떠 있을 때 트레이의 알림을 누른 경우. 화면이 이미 있어 바로 옮긴다.
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _goTo(destinationForPushData(message.data)),
    );
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

  /// 알림이 가리키는 화면을 연다. 갈 곳이 없으면 아무것도 하지 않는다.
  ///
  /// 홈을 갈아치우지 않고 그 위에 쌓는다. 알림으로 들어온 사람이 뒤로가기를
  /// 눌렀을 때 앱이 꺼지지 않고 홈으로 돌아가야 하기 때문이다.
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

  /// 로그인하면 이 기기를 등록하고, 로그아웃하면 기기 토큰을 버린다.
  ///
  /// 버리는 쪽이 필요한 이유는 [unregisterDevice] 를 못 부르는 로그아웃이 있어서다.
  /// 리프레시 토큰까지 만료돼 인터셉터가 세션을 끊을 때가 그렇다 — 그때는 인증이
  /// 이미 안 통해 서버에 해제를 알릴 방법이 없다. 그대로 두면 서버에는 이 토큰이
  /// 직전 회원 것으로 남아 알림이 계속 온다.
  ///
  /// 로그아웃 버튼으로 나갔을 때도 똑같이 버린다. 조건을 나누지 않는 것은
  /// **[unregisterDevice] 가 실패했을 수도 있기 때문이다**(기기가 오프라인이면
  /// 그 요청은 그냥 무시된다). 버리는 쪽은 서버가 필요 없어 그 경우에도 듣는다.
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
  ///
  /// **반드시 세션을 비우기 전에 불러야 한다.** 서버는 이 요청을 보낸 사람이
  /// 누군지 인증 헤더로 알아내는데, 세션을 먼저 비우면 헤더가 붙지 않아 401 로
  /// 튕기고 토큰이 서버에 그대로 남는다. 등록 API 와 달리 토큰만으로는 안 된다.
  ///
  /// 지우지 않으면 서버에는 이 토큰이 직전 회원 것으로 남는다. 같은 기기에서
  /// 다른 계정이 로그인하기 전까지는 직전 회원의 알림이 이 기기로 계속 온다.
  /// 알림 본문에는 공연명이 들어가므로 무엇을 예매했는지가 드러난다.
  ///
  /// 기기의 FCM 토큰 자체는 그대로 둔다. 다시 로그인하면 [_onSessionChanged] 가
  /// 같은 토큰을 새 회원으로 등록한다.
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

  /// 이 기기의 FCM 토큰 자체를 버린다. 로그아웃할 때 [_onSessionChanged] 가 부른다.
  ///
  /// 서버에 해제를 알리지 못한 채 로그아웃한 경우의 뒷문이다. 버린 토큰으로 온
  /// 발송은 FCM 이 "없는 토큰" 으로 답하고, 서버는 그 응답을 보고 자기 쪽 기록을
  /// 지운다. 우리가 알리지 못해도 결국 정리된다.
  ///
  /// 버리면 FCM 이 곧 새 토큰을 내주고 [start] 가 걸어 둔 구독이 [_token] 을
  /// 갈아끼운다. 다음 로그인 때 그 새 토큰이 등록된다.
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
  ///
  /// 이동 정보를 배너에 함께 실어 둔다. 눌렸을 때 [_onBannerTapped] 가 받는 것은
  /// 여기 넣은 문자열뿐이라, 안 실으면 어느 화면으로 갈지 알 길이 없다.
  ///
  /// **본문은 펼침으로 띄운다.** 양도 매물 알림은 공연 목록이 붙어 네 줄까지 오는데,
  /// 그냥 띄우면 첫 줄만 보이고 잘린다. 앱이 뒤에 있을 때 뜨는 트레이 알림은 시스템이
  /// 그려 알아서 펼쳐지므로, 여기만 맞춰 주면 두 경우가 같아진다.
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

  /// 배너를 구분하는 번호. 같은 번호로 띄우면 덮어쓰고, 다르면 따로 쌓인다.
  ///
  /// 알림함의 알림 번호를 그대로 쓴다. 같은 알림이 두 번 와도 하나로 합쳐지고,
  /// 다른 알림끼리는 안 섞인다. 번호가 없으면 내용으로 대신하는데, 그때는 문구가
  /// 같은 두 알림이 서로 덮어쓸 수 있다.
  ///
  /// 안드로이드의 알림 번호는 32비트라 서버의 큰 번호가 그대로는 안 들어간다.
  /// 아래 비트만 남겨 줄인다 — 한 기기에 동시에 떠 있는 알림끼리만 겹치지 않으면
  /// 되므로 이 정도로 충분하다.
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
  }
}
