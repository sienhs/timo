import '../constants.dart';
import 'verification_result.dart';

/// 검표 서버에 닿고 있는지.
///
/// 와이파이 연결 여부가 아니라 **마지막 검증이 서버까지 갔는지**로 판단한다.
/// 공연장 입구에서 문제가 되는 건 언제나 후자다 — 와이파이 막대는 가득 차 있는데
/// 서버 응답만 안 오는 상황이 실제로 흔하고, 그때 운영자가 알아야 하는 것은
/// "지금 검표가 되고 있는가" 하나다. 연결 상태 패키지를 붙이지 않은 이유이기도
/// 하다.
///
/// 앱을 켜고 아직 한 번도 안 찍었으면 [unknown] 이다. 그때 '온라인' 으로 적으면
/// 확인한 적 없는 것을 확인했다고 말하는 셈이 된다.
enum ServerStatus {
  unknown(ScanStrings.serverUnknown),
  online(ScanStrings.serverOnline),
  offline(ScanStrings.serverOffline);

  const ServerStatus(this.label);

  final String label;

  /// 검증 한 건의 결과가 말해 주는 서버 상태.
  ///
  /// 거절도 서버가 판정해 준 것이라 [online] 이다. [Undetermined] 만 "서버에
  /// 닿지 못했다" 는 뜻이다.
  static ServerStatus of(VerificationResult result) =>
      result is Undetermined ? ServerStatus.offline : ServerStatus.online;
}
