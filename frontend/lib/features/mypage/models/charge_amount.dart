import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// 충전 화면에 입력된 금액과, 그 금액을 보낼 수 있는지의 판정.
///
/// 화면이 "얼마인가" 와 "보내도 되는가" 를 따로 들고 있으면 버튼 활성 조건과
/// 안내 문구 조건이 갈라진다. 둘을 한 값에 묶어 화면은 [canSubmit] 과
/// [errorMessage] 만 본다.
///
/// 한도는 서버 규약이 아직 없어 화면이 잡는 값이다. 규약이 나오면 [min]·[max]
/// 만 바꾸면 버튼·문구·입력칸 자릿수가 함께 따라온다.
class ChargeAmount {
  const ChargeAmount(this.value);

  /// 아무것도 입력하지 않은 상태.
  const ChargeAmount.empty() : value = 0;

  /// 입력칸 글자에서 만든다. 쉼표처럼 숫자가 아닌 것은 걷어낸다.
  factory ChargeAmount.parse(String text) =>
      ChargeAmount(int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0);

  /// 충전할 금액(MSR). 비어 있으면 0 이다.
  final int value;

  /// 시안의 금액 칸 여섯 개. 순서가 격자 순서다.
  static const presets = <int>[5000, 10000, 30000, 50000, 100000, 150000];

  static const min = 1000;
  static const max = 1000000;

  /// 입력칸이 받는 최대 자릿수. [max] 가 일곱 자리다. 더 치면 포매터가
  /// 잘라내므로 화면에 한도를 한참 넘는 금액이 찍히지 않는다.
  static const maxDigits = 7;

  bool get isEmpty => value <= 0;

  bool get canSubmit => !isEmpty && value >= min && value <= max;

  /// 입력칸 아래에 띄울 문구. 보낼 수 있거나 아직 비어 있으면 null 이다 —
  /// 화면에 들어오자마자 빈 칸을 나무라지 않는다.
  String? get errorMessage {
    if (isEmpty || canSubmit) return null;
    return value < min
        ? MyPageStrings.chargeBelowMin(formatThousands(min))
        : MyPageStrings.chargeAboveMax(formatThousands(max));
  }

  @override
  bool operator ==(Object other) =>
      other is ChargeAmount && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
