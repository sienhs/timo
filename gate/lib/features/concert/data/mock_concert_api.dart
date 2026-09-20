import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/concert_summary.dart';
import 'concert_api.dart';

/// 서버 없이 공연 선택 화면을 돌려 보는 가짜 구현.
///
/// 오늘 공연 하나, 앞으로 할 공연 둘, 지나간 공연 하나를 준다 — 목록 정렬과
/// '오늘' 뱃지가 실기기에서 제대로 보이는지 확인하려면 네 가지가 다 있어야
/// 한다. 포스터는 없다(회색 자리로 그려진다).
///
/// [failing] 이면 매번 서버 장애를 흉내 낸다(다시 시도 화면용).
class MockConcertApi implements ConcertApi {
  MockConcertApi({this.failing = false, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final bool failing;
  final DateTime Function() _clock;

  @override
  Future<List<ConcertSummary>> findAll({String? keyword}) async {
    await Future<void>.delayed(ConcertMetrics.mockLatency);
    if (failing) {
      throw const ApiException('공연 목록을 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
    }

    final trimmed = keyword?.trim().toLowerCase() ?? '';
    final all = _concerts(_clock());
    if (trimmed.isEmpty) return all;
    return all
        .where((concert) => concert.title.toLowerCase().contains(trimmed))
        .toList();
  }

  /// 기준 시각에 맞춰 만들어 준다. 날짜를 고정값으로 박아 두면 하루만 지나도
  /// '오늘' 공연이 사라져 뱃지를 볼 수 없다.
  List<ConcertSummary> _concerts(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      ConcertSummary(
        id: 1,
        title: '2026 ㅇㅇㅇ 단독 콘서트 〈TIMO〉',
        venueName: '올림픽공원 체조경기장',
        startDate: today.add(const Duration(hours: 19)),
        endDate: today.add(const Duration(hours: 21, minutes: 30)),
      ),
      ConcertSummary(
        id: 2,
        title: '서울 재즈 페스티벌 2026',
        venueName: '난지한강공원',
        startDate: today.add(const Duration(days: 12, hours: 14)),
        endDate: today.add(const Duration(days: 14, hours: 22)),
      ),
      ConcertSummary(
        id: 3,
        title: '뮤지컬 〈레미제라블〉 내한',
        venueName: '블루스퀘어 신한카드홀',
        startDate: today.add(const Duration(days: 40, hours: 20)),
      ),
      ConcertSummary(
        id: 4,
        title: '2025 연말 가요대전',
        venueName: 'KSPO DOME',
        startDate: today.subtract(const Duration(days: 30)),
      ),
    ];
  }
}
