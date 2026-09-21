import 'package:flutter/foundation.dart';

import 'verification_result.dart';

/// 앱을 켠 뒤 **이 단말이** 찍은 횟수.
///
/// 서버 집계가 아니다. 공연 전체의 검표 완료율은 서버만 알 수 있고 그걸 주는
/// API 는 아직 없다. 여기 숫자는 "내가 지금까지 몇 장 찍었나" 로, 운영자가 교대할
/// 때나 줄이 밀릴 때 자기 속도를 가늠하는 용도다. 앱을 다시 켜면 0 부터 센다.
///
/// [rejected] 는 거절과 확인 실패를 합친다. 둘을 나눠 봐야 운영자가 할 일이
/// 갈리지 않고, 셋을 한 줄에 늘어놓으면 숫자가 작아져 서서 보기 어렵다.
@immutable
class ScanTally {
  const ScanTally({this.admitted = 0, this.rejected = 0});

  final int admitted;
  final int rejected;

  int get total => admitted + rejected;

  /// 결과 한 건을 더한 새 집계. 원본은 그대로 둔다.
  ScanTally plus(VerificationResult result) => switch (result) {
    Admitted() => ScanTally(admitted: admitted + 1, rejected: rejected),
    Rejected() || Undetermined() => ScanTally(
      admitted: admitted,
      rejected: rejected + 1,
    ),
  };
}
