import '../constants.dart';
import '../models/show_detail.dart';
import 'mock_show_detail_data.dart';
import 'show_api.dart';

/// 서버 없이 쓰는 가짜 [ShowApi]. 화면 테스트가 쓴다.
///
/// 응답마다 [latency] 만큼 기다려 실제 서버처럼 로딩 상태가 보이게 한다.
/// 테스트에서 기다릴 필요가 없으면 `Duration.zero` 를 넣는다.
///
/// 내 티켓·예매와 달리 실행 인자(`--dart-define`)로 고를 수 있게 하지 않았다.
/// 저쪽은 서버 데이터로 만들 수 없는 화면이 있어서 필요했지만, 공연 상태
/// 네 가지는 로컬 시드 공연 넷에 하나씩 들어 있어 서버로 다 볼 수 있다.
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
