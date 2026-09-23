import '../constants.dart';
import '../models/show_detail.dart';
import 'mock_show_detail_data.dart';
import 'show_api.dart';

/// 서버 없이 쓰는 가짜 [ShowApi]. 화면 테스트가 쓴다.
/// 응답마다 [latency] 만큼 기다려 실제 서버처럼 로딩 상태가 보이게 한다.
/// 테스트에서 기다릴 필요가 없으면 `Duration.zero` 를 넣는다.
class MockShowApi implements ShowApi {
  const MockShowApi({this.latency = ShowDetailMetrics.mockLatency});

  final Duration latency;

  @override
  Future<ShowDetail> fetchShowDetail(int concertId) async {
    // 지연이 0 이면 타이머를 만들지 않는다. 0 짜리 타이머도 타이머라, 프레임을
    // 한 번만 그리는 위젯 테스트가 끝날 때 "아직 남은 타이머" 로 잡힌다.
    if (latency != Duration.zero) await Future.delayed(latency);
    return MockShowDetailData.byId(concertId);
  }
}
