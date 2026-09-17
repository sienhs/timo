import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/gate_target.dart';
import '../models/verification_result.dart';
import 'scan_api.dart';

/// 백엔드 검표 API(`POST /api/v1/gates/entries/verify`)에 실제로 요청하는 [ScanApi].
///
/// 요청은 QR 문자열 그대로와 공연 ID 둘이다. 앱은 QR 을 해석하지 않는다 — 형식·
/// 서명·만료·소유자·상태 판단은 전부 서버가 한다(백엔드 GateEntryVerifyRequestDto).
///
/// 응답은 거절도 200 이다. `{ admitted: true }` 또는
/// `{ admitted: false, reasonCode: "EXPIRED" }`. 그래서 4xx/5xx 는 전부 "판정을
/// 못 했다" 로만 다루면 되고, 그 경우 [ApiException] 이 나가 화면이 [Undetermined]
/// 로 바꾼다. 401(토큰 없음·만료)·403(관리자 아님)도 여기 포함된다 — 401 은
/// AuthInterceptor 가 먼저 재발급을 시도하고, 그래도 안 되면 로그아웃시킨다.
///
/// 관리자 토큰은 AuthInterceptor 가 붙이므로 이 클래스는 인증을 모른다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpScanApi implements ScanApi {
  HttpScanApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  /// 백엔드 GateEntryController.BASE_PATH + GateEntryApi 매핑.
  static const verifyPath = '/api/v1/gates/entries/verify';

  final Dio _dio;

  @override
  Future<VerificationResult> verify({
    required String payload,
    required GateTarget target,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        verifyPath,
        data: {'qr': payload, 'concertId': target.concertId},
      );
    } on DioException catch (e) {
      throw ApiException.from(e);
    }

    final body = response.data;
    // 프록시가 HTML 을 준 경우 등. 형 변환 오류 대신 안내 문구를 화면에 넘긴다.
    if (body is! Map<String, dynamic> || body['admitted'] is! bool) {
      throw ApiException(
        '서버 응답을 읽을 수 없어요. 다시 스캔해주세요.',
        status: response.statusCode,
      );
    }

    return body['admitted'] as bool
        ? const Admitted()
        : Rejected.fromJson(body);
  }
}
