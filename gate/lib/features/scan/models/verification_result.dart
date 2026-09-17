/// 검증 한 건의 결과. 화면은 이 세 가지만 구분해 그린다.
///
/// [Admitted]·[Rejected] 는 서버(또는 목)가 판정한 결과다. [Undetermined] 는
/// 서버에 닿지 못해 판정 자체를 못 한 경우로, API 가 던진 `ApiException` 을
/// 스캔 화면이 이 형태로 바꾼다. 셋을 한 타입에 둔 이유는 결과 화면이 같은
/// 자리에 같은 방식으로 그리기 때문이다.
///
/// 좌석·예매자 정보는 싣지 않는다(팀 결정). 게이트에서는 "들여보낼지" 만
/// 판단하면 되고, 관람객 정보를 단말 화면에 띄우는 것은 개인정보만 늘린다.
sealed class VerificationResult {
  const VerificationResult();
}

/// 입장 허용. 티켓은 서버에서 USED 로 바뀌었다.
class Admitted extends VerificationResult {
  const Admitted();
}

/// 입장 거절. 사유는 서버 코드로 오고 [RejectReason] 이 문구로 바꾼다.
class Rejected extends VerificationResult {
  const Rejected({required this.reason});

  factory Rejected.fromJson(Map<String, dynamic> json) =>
      Rejected(reason: RejectReason.fromCode(json['reasonCode'] as String));

  final RejectReason reason;
}

/// 판정 못 함. 네트워크·서버 장애. 티켓 상태는 바뀌지 않았으므로 다시 스캔한다.
class Undetermined extends VerificationResult {
  const Undetermined({required this.message});

  final String message;
}

/// 거절 사유. 요구사항 "입장 검증 도메인" 의 실패 조건을 그대로 옮겼다.
///
/// [code] 는 서버 응답의 `reasonCode` 와 같아야 한다. 백엔드 계약이 확정되면
/// 이 값만 맞춘다. 모르는 코드가 오면 [unknown] 으로 받아 앱이 죽지 않게 한다 —
/// 서버에 사유가 하나 늘어도 게이트는 계속 돌아야 한다.
enum RejectReason {
  /// 유효 시간(30초)이 지난 QR. 캡처 이미지도 대부분 여기서 걸린다.
  expired('EXPIRED', 'QR 유효 시간이 지났어요'),

  /// 같은 티켓으로 두 번째 입장.
  alreadyUsed('ALREADY_USED', '이미 입장한 티켓이에요'),

  /// 예매 취소·주최사 회수로 REVOKED 된 티켓.
  revoked('REVOKED', '취소·회수된 티켓이에요'),

  /// 이 단말이 검표하는 공연의 티켓이 아니다.
  wrongConcert('WRONG_CONCERT', '다른 공연의 티켓이에요'),

  /// 지갑 서명이 현재 소유자와 맞지 않는다. 양도 뒤 이전 소유자가 쓰는 경우.
  signatureMismatch('SIGNATURE_MISMATCH', '티켓 소유자가 아니에요'),

  /// 형식이 다르거나 서명이 깨졌다. 위조 또는 우리 QR 이 아님.
  invalid('INVALID', '유효하지 않은 QR 이에요'),

  /// 앱이 모르는 코드. 서버 문구를 그대로 보여주지 않고 중립 문구로.
  unknown('UNKNOWN', '입장할 수 없는 티켓이에요');

  const RejectReason(this.code, this.label);

  /// 서버 응답 코드.
  final String code;

  /// 운영자가 보는 사유 한 줄.
  final String label;

  static RejectReason fromCode(String code) => values.firstWhere(
    (reason) => reason.code == code,
    orElse: () => RejectReason.unknown,
  );
}
