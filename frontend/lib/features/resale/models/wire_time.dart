/// 서버가 준 시각 문자열을 [DateTime] 으로 읽는다.
///
/// 서버는 `LocalDateTime` 을 시간대 없는 ISO 문자열(`2026-10-10T19:00:00`)로
/// 준다. `DateTime.parse` 는 이를 기기 현지 시각으로 읽는다.
///
/// 마켓 응답은 시각 필드가 많고(공연 일시·등록 시각·마감 시각·체결 시각) 그중
/// 여럿이 비어 올 수 있어, 모델마다 같은 함수를 하나씩 두는 대신 도메인 안에
/// 한 번만 둔다.
library;

/// 값이 문자열이 아니면(없는 필드, null) null 이다.
DateTime? dateTimeOrNull(Object? value) =>
    value is String ? DateTime.parse(value) : null;
