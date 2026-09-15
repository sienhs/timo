import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/show_detail.dart';
import '../models/zone_price.dart';
import 'show_api.dart';

/// 백엔드 공연 API 에 실제로 요청하는 [ShowApi].
///
/// **v1(실제 구현)에 붙는다.** 홈 목록이 아직 v0 스텁을 보는 것과 다른데,
/// 상세에서 이어지는 예매(구역·좌석)가 v1 이라 상세도 같은 곳을 봐야 화면에
/// 찍힌 공연과 실제로 파는 공연이 같아진다.
///
/// 한 화면을 채우는 데 요청이 둘이다. 공연 응답에는 **금액이 없고**, 가격은
/// 구역이 들고 있기 때문이다. 순서가 상관없으므로 나란히 보낸다. 둘의 무게는
/// 다르다 — 공연이 실패하면 화면이 실패하지만, 구역이 실패하면 가격 자리만
/// 비운다([_zonePricesOrEmpty]).
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
  static const sectionsPath = '/api/v1/sections';

  final Dio _dio;

  @override
  Future<ShowDetail> fetchShowDetail(int concertId) async {
    // 먼저 둘 다 보내 놓고 나중에 기다린다. 순서가 상관없는 요청을 줄 세우면
    // 화면이 두 번 왕복하는 만큼 늦게 뜬다.
    final concert = _guard(() => _dio.get<dynamic>('$concertsPath/$concertId'));
    final zonePrices = _zonePricesOrEmpty(concertId);

    return ShowDetail.fromJson(
      _body(await concert),
      zonePrices: await zonePrices,
    );
  }

  /// 구역 목록에서 가격 줄을 만든다. **실패하면 빈 목록을 돌려준다.**
  ///
  /// 공연은 누구나 볼 수 있지만 구역·좌석은 로그인해야 열린다. 둘을 한 몸으로
  /// 묶으면 로그인 전 사용자는 공연 상세를 아예 열지 못한다 — 예매하러 들어올
  /// 길이 막히는 셈이다. 가격이 비면 화면이 그 자리만 비워 둔다.
  ///
  /// 등급으로 묶지 않는다. 서버 등급이 `COMMON` 하나뿐이라 묶으면 공연장
  /// 전체가 한 줄이 된다(`ZonePrice` 주석 참고).
  Future<List<ZonePrice>> _zonePricesOrEmpty(int concertId) => _dio
      .get<dynamic>(sectionsPath, queryParameters: {'concertId': concertId})
      .then(_zonePrices)
      .onError((_, _) => const []);

  List<ZonePrice> _zonePrices(Response<dynamic> response) {
    final sections = _body(response)['sections'];
    if (sections is! List) throw _unreadable(response);
    return sections
        .whereType<Map<String, dynamic>>()
        .map(ZonePrice.fromJson)
        .toList();
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
