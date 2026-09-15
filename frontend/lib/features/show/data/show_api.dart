import '../models/show_detail.dart';

/// 공연 상세 화면이 서버에 묻는 것.
///
/// 화면은 이 약속만 알고, 실제로 서버에 가는지(`HttpShowApi`) 고정 데이터를
/// 돌려주는지(`MockShowApi`) 는 앱이 정한다.
abstract class ShowApi {
  /// 공연 한 건의 상세를 가져온다. 화면에 필요한 가격까지 채워서 돌려준다.
  Future<ShowDetail> fetchShowDetail(int concertId);
}
