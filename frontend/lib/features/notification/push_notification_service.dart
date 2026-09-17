import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/network/api_client.dart';
import '../auth/state/auth_session.dart';

/// FCM 권한, 토큰 등록, 앱이 열린 상태의 배너를 한곳에서 관리한다.
///
/// 알림을 눌렀을 때의 화면 이동은 도메인별 data payload 규약이 정해지면
/// [onMessageOpenedApp] 구독 지점에 추가한다. 이 서비스는 특정 알림 종류를 모른다.
class PushNotificationService {
  PushNotificationService(
    this._session, {
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    Dio? dio,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications = localNotifications ??
           FlutterLocalNotificationsPlugin(),
       _dio = dio ?? ApiClient.dio;

  static const _devicePath = '/api/v1/notifications/devices';
  static const _channel = AndroidNotificationChannel(
    'timo_general_notifications',
    '일반 알림',
    description: '예매, 티켓, 공연 관련 알림입니다.',
    importance: Importance.high,
  );

  final AuthSession _session;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Dio _dio;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _token;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _initializeLocalNotifications();
    await _messaging.requestPermission();
    _token = await _messaging.getToken();
    await _registerCurrentToken();

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      _token = token;
      unawaited(_registerCurrentToken());
    });
    _session.addListener(_onSessionChanged);
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  void _onSessionChanged() {
    if (_session.isLoggedIn) unawaited(_registerCurrentToken());
  }

  Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(initializationSettings);
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
      debugPrint('Push token registration failed: ${error.response?.statusCode}');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(android: AndroidNotificationDetails(
        'timo_general_notifications',
        '일반 알림',
        channelDescription: '예매, 티켓, 공연 관련 알림입니다.',
        importance: Importance.high,
        priority: Priority.high,
      )),
    );
  }

  Future<void> dispose() async {
    _session.removeListener(_onSessionChanged);
    await _tokenRefreshSubscription?.cancel();
  }
}
