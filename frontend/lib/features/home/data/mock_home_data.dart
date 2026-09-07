import '../models/artist_summary.dart';
import '../models/home_banner.dart';
import '../models/show_summary.dart';

/// 홈 목업 데이터. 서버 연동 시 이 클래스를 지우고 응답으로 교체한다.
///
/// MVP 범위대로 **콘서트만** 담는다. 뮤지컬·연극·전시는 나오지 않아야 한다.
///
/// 홈의 두 줄(오픈 임박 · 인기 공연)에 실제로 나오는 공연만 둔다. 목록·검색
/// 화면이 생기면 그때 카탈로그를 넓힌다.
///
/// 포스터는 전부 같은 샘플 이미지다. 공연별 포스터 에셋이 들어오면
/// [_poster] 를 각 공연의 경로로 바꾸면 된다.
///
/// 티켓 오픈 일시만 **실행 시각 기준 상대값**으로 만든다. 고정 날짜로 두면
/// 그 날이 지나는 순간 `오늘 14:00 오픈` · `5일 후 오픈` 뱃지가 전부 지난
/// 날짜로 바뀌어, 시안의 세 가지 뱃지 형태를 시연할 수 없다.
class MockHomeData {
  MockHomeData._();

  static const _poster = 'assets/images/sample_poster.jpg';

  /// 새로 고칠 때 기다리는 시간.
  ///
  /// 목업이라 실제로 다시 받아올 것이 없다. 0 이면 안내 문구가 뜨자마자
  /// 사라져 무엇이 일어났는지 알 수 없으므로, 서버 응답 정도의 시간을
  /// 흉내낸다. API 가 붙으면 이 상수는 사라진다.
  static const refreshDelay = Duration(milliseconds: 1200);

  /// 오늘 자정. 오픈 일시를 여기서 더해 만든다.
  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static final banners = <HomeBanner>[
    HomeBanner(
      showId: _iu.id,
      title: _iu.title,
      subtitle: '고척스카이돔',
      posterAsset: _iu.posterAsset,
    ),
    HomeBanner(
      showId: _remind.id,
      title: _remind.title,
      subtitle: '올림픽공원 체조경기장',
      posterAsset: _remind.posterAsset,
    ),
    HomeBanner(
      showId: _bigbang.id,
      title: _bigbang.title,
      subtitle: '고양종합운동장',
      posterAsset: _bigbang.posterAsset,
    ),
  ];

  /// 시안의 원형 목록 순서. 마지막 '더보기' 칸은 데이터가 아니라 화면이 그린다.
  static const artists = <ArtistSummary>[
    ArtistSummary(name: '김준수'),
    ArtistSummary(name: '옥주현'),
    ArtistSummary(name: '검정치마'),
    ArtistSummary(name: '정명훈'),
    ArtistSummary(name: '아이유'),
    ArtistSummary(name: '박보검'),
    ArtistSummary(name: '페기구'),
  ];

  /// 티켓 오픈 임박. 오픈이 빠른 순으로 둔다.
  static final ticketOpenSoon = <ShowSummary>[
    _iu,
    _blackSkirt,
    _remind,
    _bigbang,
  ];

  /// 인기 공연. 목록 순서가 곧 순위다(1위부터).
  static final popular = <ShowSummary>[
    _remind,
    _bigbang,
    _iu,
    _xia,
    _peggyGou,
  ];

  static final _iu = ShowSummary(
    id: 'iu-2026',
    title: '2026 아이유 콘서트',
    posterAsset: _poster,
    startAt: DateTime(2026, 11, 1),
    endAt: DateTime(2026, 12, 31),
    // 오늘 오픈 — 시안의 `오늘 14:00 오픈` 뱃지가 여기서 나온다.
    ticketOpenAt: _today.add(const Duration(hours: 14)),
  );

  static final _remind = ShowSummary(
    id: 'remind-2026',
    title: 'REMIND : 리센느',
    posterAsset: _poster,
    startAt: DateTime(2026, 7, 5),
    endAt: DateTime(2026, 7, 7),
    ticketOpenAt: _today.add(const Duration(days: 5, hours: 19)),
  );

  static final _bigbang = ShowSummary(
    id: 'bigbang-2026',
    title: '2026 BIGBANG',
    posterAsset: _poster,
    startAt: DateTime(2026, 11, 15),
    // 한 달 뒤 이후 — 날짜를 그대로 읽어 주는 뱃지가 여기서 나온다.
    ticketOpenAt: _today.add(const Duration(days: 48, hours: 14)),
  );

  static final _blackSkirt = ShowSummary(
    id: 'black-skirt-401',
    title: '검정치마 단독공연 : 401',
    posterAsset: _poster,
    startAt: DateTime(2026, 9, 20),
    ticketOpenAt: _today.add(const Duration(days: 2, hours: 11)),
  );

  static final _xia = ShowSummary(
    id: 'xia-2026',
    title: '2026 김준수 콘서트 : XIGNATURE',
    posterAsset: _poster,
    startAt: DateTime(2026, 9, 1),
    endAt: DateTime(2026, 9, 3),
  );




  static final _peggyGou = ShowSummary(
    id: 'peggy-gou-2026',
    title: '페기구 THE LOUD SHOW',
    posterAsset: _poster,
    startAt: DateTime(2026, 8, 15),
  );
}
