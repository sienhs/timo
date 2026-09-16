import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/member_profile.dart';
import '../models/wallet_summary.dart';
import 'mock_wallet_ledger.dart';
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

  final Dio _dio;

  /// 지갑 API 가 생기기 전까지 잔액·충전을 대신 맡는 메모리 원장. 서버가
  /// 생기면 이 필드와 아래 두 메서드의 목 본문을 함께 지운다.
  final _ledger = MockWalletLedger();

  /// 응답에 실명·전화번호가 들어 있다. 여기서는 화면에 필요한 것만 모델에
  /// 담고 나머지는 바로 버린다 — 찍어 두거나 들고 다니지 않는다.
  @override
  Future<MemberProfile> fetchProfile() async {
    final response = await _guard(() => _dio.get<dynamic>('$basePath/me'));
    return MemberProfile.fromJson(_body(response));
  }

  /// 지갑(잔액·거래 내역) API 는 백엔드에 아직 없다. 그때까지 목업을
  /// 돌려준다. API 가 생기면 이 본문만 `GET` 으로 바꾸고 [MockWalletLedger] 를
  /// 지운다 — 시그니처가 같으니 화면과 [MyPageApi] 는 손대지 않는다.
  @override
  Future<WalletSummary> fetchWallet() => Future.value(_ledger.wallet);

  /// 충전 API 도 아직 없다(요구사항 #21 은 PG 모의 연동이다). 원장에 쌓아 두면
  /// 앱을 켜 둔 동안은 마이페이지 잔액과 사용 내역에 충전이 반영된다.
  /// API 가 생기면 이 본문만 `POST` 로 바꾼다.
  @override
  Future<WalletSummary> charge(int amount) =>
      Future.value(_ledger.charge(amount));

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
