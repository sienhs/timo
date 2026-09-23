import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/member_profile.dart';
import '../models/wallet_summary.dart';
import 'my_page_api.dart';

/// 백엔드 회원 API(`/api/v1/members`)에 실제로 요청하는 [MyPageApi].
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 토큰을 붙이는
/// 일은 `AuthInterceptor` 가, 서버 주소·시간 제한·로그는 [ApiClient] 가,
/// 실패 응답을 화면용 문구로 바꾸는 일은 [ApiException] 이 맡는다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpMyPageApi implements MyPageApi {
  HttpMyPageApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const basePath = '/api/v1/members';
  static const walletPath = '$basePath/wallet';
  static const chargePath = '$walletPath/charge';

  final Dio _dio;

  /// 응답에 실명·전화번호가 들어 있다. 여기서는 화면에 필요한 것만 모델에
  /// 담고 나머지는 바로 버린다 — 찍어 두거나 들고 다니지 않는다.
  @override
  Future<MemberProfile> fetchProfile() async {
    final response = await _guard(() => _dio.get<dynamic>('$basePath/me'));
    return MemberProfile.fromJson(_body(response));
  }

  /// 같은 응답에서 실명만 꺼낸다. 모델에 담지 않고 문자열 하나로 돌려주므로
  /// 부른 쪽이 쓰고 버릴 수 있다 — 왜 [fetchProfile] 과 나눠 두는지는
  /// [MyPageApi.fetchBookerName] 주석에 있다.
  @override
  Future<String> fetchBookerName() async {
    final response = await _guard(() => _dio.get<dynamic>('$basePath/me'));
    return _body(response)['name'] as String;
  }

  /// 누구의 지갑인지는 토큰의 `sub` 가 정하므로 회원 번호를 싣지 않는다.
  @override
  Future<WalletSummary> fetchWallet() async {
    final response = await _guard(() => _dio.get<dynamic>(walletPath));
    return WalletSummary.fromJson(_body(response));
  }

  /// 충전 응답은 조회와 같은 모양이라, 화면이 [fetchWallet] 을 다시 부르지
  /// 않고 이 결과만으로 새 잔액과 내역을 그린다.
  ///
  /// 0 이하를 보내면 서버가 400 을 주지만, 그 전에 화면(`ChargeAmount`)이
  /// 거른다.
  @override
  Future<WalletSummary> charge(int amount) async {
    final response = await _guard(
      () => _dio.post<dynamic>(chargePath, data: {'amount': amount}),
    );
    return WalletSummary.fromJson(_body(response));
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// 성공 응답 본문. JSON 객체가 아니면(프록시가 HTML 을 준 경우 등) 화면용
  /// 예외로 바꿔서, 화면이 형 변환 오류 대신 안내 문구를 받게 한다.
  Map<String, dynamic> _body(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw ApiException(
      MyPageStrings.unreadableResponse,
      status: response.statusCode,
    );
  }
}
