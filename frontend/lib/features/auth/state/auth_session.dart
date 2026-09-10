import 'package:flutter/foundation.dart';

import '../data/token_storage.dart';
import '../models/auth_tokens.dart';

/// 앱 전체가 공유하는 로그인 상태.
///
/// 로그인·가입에 성공하면 [signIn] 으로 토큰을 담고 기기에 저장한다. 앱을 켤 때
/// [restore] 로 저장된 것을 되살리고, [signOut] 이면 비우고 지운다. 값이 바뀌면
/// 알려서(ChangeNotifier) [AuthSessionScope] 아래 화면들이 다시 그려진다.
///
/// 토큰 재발급은 백엔드 API 가 아직 없어 하지 않는다. 로그인이 필요한 API 가
/// 401 을 주면 인터셉터가 [signOut] 을 불러 로그아웃 상태로 돌린다. 재발급 API 가
/// 생기면 그 자리를 "재발급 시도 → 실패하면 로그아웃" 으로 바꾼다.
///
/// [now] 는 테스트에서 시계를 고정하기 위해 받는다. 앱에서는 넘기지 않는다.
class AuthSession extends ChangeNotifier {
  AuthSession({required this._storage, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final TokenStorage _storage;
  final DateTime Function() _now;

  int? _memberId;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiresAt;

  bool get isLoggedIn => _accessToken != null;

  int? get memberId => _memberId;

  String? get accessToken => _accessToken;

  String? get refreshToken => _refreshToken;

  DateTime? get accessTokenExpiresAt => _accessTokenExpiresAt;

  /// 액세스 토큰 수명이 지났는지. 로그아웃 상태면 true 다(쓸 토큰이 없으니).
  bool get isAccessTokenExpired {
    final expiresAt = _accessTokenExpiresAt;
    return expiresAt == null || !_now().isBefore(expiresAt);
  }

  /// 기기에 저장된 로그인 정보를 되살린다. 앱을 켤 때 한 번 부른다.
  ///
  /// 네 값 중 하나라도 없거나 깨져 있으면 로그아웃 상태로 두고 남은 값도 지운다.
  /// 반쪽짜리 상태(토큰은 있는데 회원 번호가 없는 식)로 두는 것보다 다시 로그인
  /// 하게 하는 쪽이 안전하다.
  Future<void> restore() async {
    final memberId = int.tryParse(
      await _storage.read(TokenStorageKeys.memberId) ?? '',
    );
    final accessToken = await _storage.read(TokenStorageKeys.accessToken);
    final refreshToken = await _storage.read(TokenStorageKeys.refreshToken);
    final expiresAt = DateTime.tryParse(
      await _storage.read(TokenStorageKeys.accessTokenExpiresAt) ?? '',
    );

    if (memberId == null ||
        accessToken == null ||
        refreshToken == null ||
        expiresAt == null) {
      await _clearStorage();
      return;
    }

    _memberId = memberId;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _accessTokenExpiresAt = expiresAt;
    notifyListeners();
  }

  /// 로그인·가입 성공 응답을 담고 기기에 저장한다.
  ///
  /// 서버가 준 "남은 초" 는 지금 시각에 더해 절대 시각으로 바꿔 둔다. 그래야
  /// 앱을 다시 켰을 때도 만료 여부를 알 수 있다.
  Future<void> signIn(AuthTokens tokens) async {
    _memberId = tokens.memberId;
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _accessTokenExpiresAt = _now().add(tokens.accessTokenExpiresIn);
    notifyListeners();

    await _storage.write(TokenStorageKeys.memberId, tokens.memberId.toString());
    await _storage.write(TokenStorageKeys.accessToken, tokens.accessToken);
    await _storage.write(TokenStorageKeys.refreshToken, tokens.refreshToken);
    await _storage.write(
      TokenStorageKeys.accessTokenExpiresAt,
      _accessTokenExpiresAt!.toIso8601String(),
    );
  }

  /// 로그아웃. 상태를 비우고 기기에서도 지운다.
  ///
  /// 서버 쪽 세션(리프레시 토큰)은 그대로 남는다. 서버에 알리는 로그아웃 API 가
  /// 아직 없기 때문이다. 기기 식별자는 지우지 않는다([TokenStorageKeys.deviceId]).
  Future<void> signOut() async {
    _memberId = null;
    _accessToken = null;
    _refreshToken = null;
    _accessTokenExpiresAt = null;
    notifyListeners();

    await _clearStorage();
  }

  Future<void> _clearStorage() async {
    await _storage.delete(TokenStorageKeys.memberId);
    await _storage.delete(TokenStorageKeys.accessToken);
    await _storage.delete(TokenStorageKeys.refreshToken);
    await _storage.delete(TokenStorageKeys.accessTokenExpiresAt);
  }
}
