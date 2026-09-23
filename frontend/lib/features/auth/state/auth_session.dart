import 'package:flutter/foundation.dart';

import '../data/token_storage.dart';
import '../models/auth_tokens.dart';
import '../models/reissued_access_token.dart';

/// 앱 전체가 공유하는 로그인 상태. [signIn] 으로 토큰을 담아 기기에 저장하고,
/// 앱을 켤 때 [restore] 로 되살리며 [signOut] 이면 비우고 지운다. 인터셉터가
/// 재발급받은 토큰은 [renewAccessToken] 으로 갈아끼운다. [now] 는 테스트용이다.
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

  /// 기기에 저장된 로그인 정보를 되살린다. 앱을 켤 때 한 번 부른다. 네 값 중
  /// 하나라도 없거나 깨져 있으면 로그아웃 상태로 되돌리고 남은 값도 지운다.
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

  /// 로그인·가입 성공 응답을 담고 기기에 저장한다. 서버가 준 "남은 초" 는 절대
  /// 시각으로 바꿔 둬야 앱을 다시 켰을 때도 만료 여부를 알 수 있다.
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

  /// 재발급받은 액세스 토큰만 갈아끼운다. 인터셉터가 부른다. 리프레시 토큰은
  /// 회전하지 않아 그대로 둔다. 서버를 다녀오는 사이 로그아웃했으면 새 토큰을
  /// 넣어 다시 로그인 상태가 되지 않도록 로그아웃 상태면 아무것도 하지 않는다.
  Future<void> renewAccessToken(ReissuedAccessToken reissued) async {
    if (!isLoggedIn) return;

    _accessToken = reissued.accessToken;
    _accessTokenExpiresAt = _now().add(reissued.expiresIn);
    notifyListeners();

    await _storage.write(TokenStorageKeys.accessToken, reissued.accessToken);
    await _storage.write(
      TokenStorageKeys.accessTokenExpiresAt,
      _accessTokenExpiresAt!.toIso8601String(),
    );
  }

  /// 로그아웃. 상태를 비우고 기기에서도 지운다. 서버 세션은 여기서 안 끊는다.
  /// 401 을 받은 인터셉터도 부르는데 그땐 알릴 게 없고, 버튼 쪽이 따로
  /// AuthApi.logout 을 부른다. 기기 식별자([TokenStorageKeys.deviceId])는 남긴다.
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
