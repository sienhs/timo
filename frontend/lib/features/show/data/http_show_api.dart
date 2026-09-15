import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/show_detail.dart';
import 'show_api.dart';

/// 백엔드 공연 API 에 실제로 요청하는 [ShowApi].
///
/// **v1(실제 구현)에 붙는다.** 홈 목록이 아직 v0 스텁을 보는 것과 다른데,
/// 상세에서 이어지는 예매(구역·좌석)가 v1 이라 상세도 같은 곳을 봐야 화면에
/// 찍힌 공연과 실제로 파는 공연이 같아진다.
///
/// 한 화면을 요청 **하나**로 채운다. 예전에는 가격을 얻으려고 구역 목록을 한
/// 번 더 불렀는데, 상세 응답이 구역별 가격(`sectionPrices`)을 함께 주게 되어
/// 그 요청을 걷어냈다. 화면이 빨리 뜨는 것보다 중요한 건, **구역 목록은
/// 로그인해야 열리는 주소라 로그인 전 사용자에게는 가격이 아예 안 보였다**는
/// 점이다. 상세는 로그인 없이 열리므로 이제 누구나 가격을 본다.
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 서버 주소·시간
/// 제한·로그는 [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은
/// [ApiException] 이 맡는다.
///
/// **로컬 서버에서 알아둘 것.** 상세를 부를 때마다 서버가 조회수를 1 올린다.
/// 화면이 들어올 때 한 번만 부르고 새로고침 버튼을 두지 않은 이유다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpShowApi implements ShowApi {
  HttpShowApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const concertsPath = '/api/v1/concerts';

  final Dio _dio;

  @override
  Future<ShowDetail> fetchShowDetail(int concertId) async {
    final response = await _guard(
      () => _dio.get<dynamic>('$concertsPath/$concertId'),
    );
    return ShowDetail.fromJson(_body(response));
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  ///
  /// `HttpAuthApi` · `HttpHomeApi` · `HttpTicketApi` · `HttpBookingApi` 와
  /// 같다. 다섯 곳이 같은 코드를 들고 있으니 `core/network` 로 올릴 때가 됐다.
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
    throw _unreadable(response);
  }

  ApiException _unreadable(Response<dynamic> response) => ApiException(
    ShowDetailStrings.unreadableResponse,
    status: response.statusCode,
  );
}
