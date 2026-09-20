import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/favorite_show.dart';
import 'favorite_api.dart';

/// 서버 없이 도는 [FavoriteApi]. 위젯 테스트와 시안 확인에 쓴다.
///
/// 찜 목록을 메모리에 들고 있으면서 등록·해제를 그대로 반영한다. 등록은 공연
/// 번호만 받으므로(서버 규약이 그렇다) 목록에 없던 공연을 찜하면 번호만 남는다
/// — [fetchShows] 는 그런 공연을 돌려주지 못한다. 목록에 보여야 하는 테스트는
/// [MockFavoriteApi.new] 의 [shows] 에 미리 넣어 둔다.
///
/// [failing] 을 켜면 모든 요청이 실패한다. 낙관적으로 채운 하트가 되돌아가는지
/// 볼 때 쓴다.
class MockFavoriteApi implements FavoriteApi {
  MockFavoriteApi({
    List<FavoriteShow> shows = const [],
    this.latency = Duration.zero,
    this.failing = false,
  }) : _shows = [...shows];

  /// 최근 찜한 순. 서버 목록과 같은 순서다.
  final List<FavoriteShow> _shows;

  final Duration latency;

  bool failing;

  /// 서버가 들고 있는 찜 공연 번호. 테스트가 "서버에도 남았는가" 를 볼 때 읽는다.
  List<int> get wishedIds => [for (final show in _shows) show.id];

  @override
  Future<List<FavoriteShow>> fetchShows() async {
    await _wait();
    return List.unmodifiable(_shows);
  }

  @override
  Future<void> addShow(int concertId) async {
    await _wait();
    // 서버와 같이 멱등이다. 이미 있으면 아무 일도 하지 않는다.
    if (_shows.any((show) => show.id == concertId)) return;
    _shows.insert(0, _placeholder(concertId));
  }

  @override
  Future<void> removeShow(int concertId) async {
    await _wait();
    _shows.removeWhere((show) => show.id == concertId);
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failing) throw const ApiException(FavoriteStrings.toggleFailed);
  }

  /// 번호만 아는 공연. 목록에 없던 공연을 찜했을 때 자리만 채운다.
  FavoriteShow _placeholder(int concertId) => FavoriteShow(
    id: concertId,
    title: '공연 $concertId',
    venueName: '',
    isOnSale: true,
  );
}
