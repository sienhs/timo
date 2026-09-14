import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import '../models/ticket_status.dart';
import 'ticket_api.dart';

/// 가짜 [TicketApi] 가 무엇을 돌려줄지.
///
/// 서버로는 만들 수 없는 상황을 골라 볼 수 있게 나눠 뒀다. v0 스텁으로는
/// 티켓을 한 장밖에 못 만들고 지난 공연은 아예 못 만든다
/// ([HttpTicketApi] 주석 참고).
enum TicketMockScenario {
  /// 시안 그대로. 예정 2장 · 지난 2장.
  design,

  /// 발행 중 · 발행 실패 · 환불됨 · 예매 취소됨. 시안에 없는 상태들이다.
  states,

  /// 두 탭 모두 빈 목록.
  empty,

  /// 모든 요청이 실패한다. 에러 화면과 다시 시도를 볼 때.
  error,
}

/// 서버 없이 쓰는 가짜 [TicketApi]. 화면 테스트와 눈으로 하는 확인이 쓴다.
///
/// `flutter run --dart-define=TICKET_API=mock` 으로 앱에 꽂을 수 있다
/// (`mock-states` · `mock-empty` · `mock-error` 도 된다). 백엔드를 띄우지 않고
/// 화면을 시안과 대조할 때 쓴다.
///
/// **날짜는 실행 시각 기준 상대값이다.** 시안에 적힌 날짜(2026.05.20 등)를
/// 그대로 박으면 그 날이 지나는 순간 예정 공연이 전부 지난 공연 탭으로 넘어가,
/// 카드 두 종류를 한 번에 볼 수 없다. 공연명·장소·좌석은 시안 그대로다.
///
/// 취소는 실제로 상태를 바꾼다. 취소 버튼을 눌렀을 때 목록이 어떻게 변하는지
/// 서버 없이 확인하기 위해서다.
///
/// 포스터만은 백엔드가 필요하다. 주소가 백엔드의 정적 파일([_posters])을
/// 가리켜서, 서버를 안 띄우면 회색 자리가 그려진다. 앱 에셋으로 두면 그 사정이
/// 없어지지만 카드가 받는 값이 서버 응답과 달라져, 정작 연동했을 때 포스터가
/// 깨지는 것을 목으로는 못 잡는다.
class MockTicketApi implements TicketApi {
  MockTicketApi({
    this.latency = TicketMetrics.mockLatency,
    this.scenario = TicketMockScenario.design,
  });

  final Duration latency;
  final TicketMockScenario scenario;

  List<MyTicket>? _tickets;

  @override
  Future<List<MyTicket>> fetchMyTickets() async {
    await _respond();
    return List.unmodifiable(_tickets ??= _initialTickets());
  }

  @override
  Future<void> cancelReservation(int reservationId) async {
    await _respond();
    final tickets = _tickets ??= _initialTickets();
    final index = tickets.indexWhere((t) => t.reservationId == reservationId);
    if (index < 0) {
      throw const ApiException('이미 없는 예매예요.', status: 404);
    }
    tickets[index] = tickets[index].copyWith(status: TicketStatus.cancelled);
  }

  /// 지연이 0 이면 타이머를 만들지 않는다. 0 짜리 타이머도 타이머라, 프레임을
  /// 한 번만 그리는 위젯 테스트가 끝날 때 "아직 남은 타이머" 로 잡힌다.
  Future<void> _respond() async {
    if (scenario == TicketMockScenario.error) {
      throw const ApiException('인터넷 연결을 확인해주세요.');
    }
    if (latency != Duration.zero) await Future<void>.delayed(latency);
  }

  List<MyTicket> _initialTickets() => switch (scenario) {
    TicketMockScenario.empty || TicketMockScenario.error => [],
    TicketMockScenario.design => [
      // 공연이 곧 시작한다 — 입장 QR 버튼이 열린 카드.
      _ticket(
        reservationId: 1,
        concertId: 11,
        title: '2026 REMIND: 리센느',
        venueName: '올림픽공원 체조경기장',
        sectionName: 'R석',
        seatRow: 12,
        seatNumber: 24,
        facePrice: 154000,
        startsIn: const Duration(hours: 1),
        posterImageUrl: _posters[0],
      ),
      // 아직 멀었다 — 상세정보 버튼만 있는 카드.
      _ticket(
        reservationId: 2,
        concertId: 12,
        title: '2026 아이유 콘서트',
        venueName: '블루스퀘어 마스터카드홀',
        sectionName: 'VIP석',
        seatRow: 5,
        seatNumber: 10,
        facePrice: 198000,
        startsIn: const Duration(days: 9),
        posterImageUrl: _posters[1],
      ),
      _ticket(
        reservationId: 3,
        concertId: 13,
        title: '2025 블랙핑크',
        venueName: '올림픽공원 체조경기장',
        sectionName: 'R석',
        seatRow: 12,
        seatNumber: 24,
        facePrice: 143000,
        startsIn: const Duration(days: -200),
        posterImageUrl: _posters[2],
      ),
      _ticket(
        reservationId: 4,
        concertId: 14,
        title: '2024 BIGBANG',
        venueName: '올림픽공원 체조경기장',
        sectionName: 'R석',
        seatRow: 12,
        seatNumber: 24,
        facePrice: 132000,
        startsIn: const Duration(days: -570),
        posterImageUrl: _posters[3],
      ),
    ],
    TicketMockScenario.states => [
      _ticket(
        reservationId: 11,
        concertId: 11,
        title: '2026 REMIND: 리센느',
        venueName: '올림픽공원 체조경기장',
        sectionName: 'R석',
        seatRow: 12,
        seatNumber: 24,
        facePrice: 154000,
        startsIn: const Duration(days: 9),
        posterImageUrl: _posters[0],
        status: TicketStatus.pendingMint,
      ),
      _ticket(
        reservationId: 12,
        concertId: 12,
        title: '2026 아이유 콘서트',
        venueName: '블루스퀘어 마스터카드홀',
        sectionName: 'VIP석',
        seatRow: 5,
        seatNumber: 10,
        facePrice: 198000,
        startsIn: const Duration(days: 14),
        posterImageUrl: _posters[1],
        status: TicketStatus.mintFailed,
      ),
      _ticket(
        reservationId: 13,
        concertId: 13,
        title: '2026 검정치마 단독 공연',
        venueName: '올림픽홀',
        sectionName: 'S석',
        seatRow: 3,
        seatNumber: 7,
        facePrice: 99000,
        startsIn: const Duration(days: 21),
        posterImageUrl: _posters[2],
        status: TicketStatus.refunded,
      ),
      _ticket(
        reservationId: 14,
        concertId: 14,
        title: '2026 박보검 팬미팅',
        venueName: '고척돔',
        sectionName: 'A석',
        seatRow: 20,
        seatNumber: 2,
        facePrice: 88000,
        startsIn: const Duration(days: 30),
        posterImageUrl: _posters[3],
        status: TicketStatus.cancelled,
      ),
    ],
  };

  MyTicket _ticket({
    required int reservationId,
    required int concertId,
    required String title,
    required String venueName,
    required String sectionName,
    required int seatRow,
    required int seatNumber,
    required int facePrice,
    required Duration startsIn,
    String? posterImageUrl,
    TicketStatus status = TicketStatus.minted,
  }) {
    final now = DateTime.now();
    return MyTicket(
      reservationId: reservationId,
      concertId: concertId,
      title: title,
      venueName: venueName,
      sectionName: sectionName,
      seatRow: seatRow,
      seatNumber: seatNumber,
      facePrice: facePrice,
      status: status,
      posterImageUrl: posterImageUrl,
      bookedAt: now.subtract(const Duration(days: 30)),
      startAt: _startAt(now, startsIn),
    );
  }

  /// 공연 시각을 고른다.
  ///
  /// 하루 넘게 떨어진 공연은 날짜만 옮기고 시각을 저녁 7시로 맞춘다. 실행
  /// 시각을 그대로 쓰면 `2026.09.14 04:33` 같은 새벽 공연이 나와 시안과 대조할
  /// 때 눈에 거슬린다. 오늘 공연만 실제 시각을 써야 입장 QR 창(시작 3시간
  /// 전부터)에 들어온다.
  static DateTime _startAt(DateTime now, Duration startsIn) {
    final at = now.add(startsIn);
    if (startsIn.inHours.abs() < 24) {
      return DateTime(at.year, at.month, at.day, at.hour, at.minute);
    }
    return DateTime(at.year, at.month, at.day, _showHour);
  }

  /// 공연다운 시각. 백엔드 고정 공연들도 19시다.
  static const _showHour = 19;

  /// 백엔드가 정적으로 서빙하는 포스터들. 서버 응답과 같은 상대 경로 모양이다.
  static const _posters = [
    'poster/poster_main_kim_feel.gif',
    'poster/poster_main_lee.gif',
    'poster/poster_main_roykim.jpg',
    'poster/poster_main_mars.gif',
  ];
}
