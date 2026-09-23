import '../models/show_detail.dart';

/// 공연 상세 화면이 서버에 묻는 것. 구현은 `HttpShowApi`(서버)·`MockShowApi`(고정 데이터).
abstract class ShowApi {
  /// 공연 한 건의 상세를 가져온다. 화면에 필요한 가격까지 채워서 돌려준다.
  Future<ShowDetail> fetchShowDetail(int concertId);
}
