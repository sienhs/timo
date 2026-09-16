import '../constants.dart';

/// 양도 등록 화면에 입력된 판매가와, 그 값을 보낼 수 있는지의 판정.
///
/// 화면이 "얼마인가" 와 "보내도 되는가" 를 따로 들고 있으면 버튼 활성 조건과
/// 안내 문구 조건이 갈라진다. 둘을 한 값에 묶어 화면은 [canSubmit] 과
/// [errorMessage] 만 본다(충전 화면의 `ChargeAmount` 와 같은 방식이다).
///
/// 상한은 화면이 정한 값이 아니라 **티켓의 정가**다. 서버도 같은 자리에서
/// 거절하므로(`ListPriceExceedsFacePriceException`) 등록 버튼을 눌러 놓고
/// 실패를 받느니 입력 단계에서 막는다.
class ListingPrice {
  const ListingPrice({required this.value, required this.faceValue});

  /// 입력칸 글자에서 만든다. 쉼표처럼 숫자가 아닌 것은 걷어낸다.
  factory ListingPrice.parse(String text, {required int faceValue}) =>
      ListingPrice(
        value: int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        faceValue: faceValue,
      );

  /// 판매가(원). 비어 있으면 0 이다.
  final int value;

  /// 상한이 되는 정가(원).
  final int faceValue;

  /// 서버가 받는 최소 등록가. 0 은 무상 전송이라 성립하지 않는다
  /// (백엔드 `CreateListingRequestDto`).
  static const min = 1;

  bool get isEmpty => value <= 0;

  bool get isOverFaceValue => value > faceValue;

  bool get canSubmit => value >= min && !isOverFaceValue;

  /// 슬라이더 손잡이 위치(0~1). 정가가 0 이하인 티켓은 있을 수 없지만,
  /// 그런 값이 와도 0 으로 나누지 않는다.
  double get ratio =>
      faceValue <= 0 ? 0 : (value / faceValue).clamp(0, 1).toDouble();

  /// 입력칸 아래에 띄울 문구. 보낼 수 있거나 아직 비어 있으면 null 이다 —
  /// 화면에 들어오자마자 빈 칸을 나무라지 않는다. 그 자리에는 화면이 안내
  /// 문구([ResaleStrings.priceHint])를 그린다.
  String? get errorMessage =>
      isOverFaceValue ? ResaleStrings.priceOverFace : null;

  /// 입력칸이 받는 최대 자릿수. 정가보다 한 자리 더 받는다 — 딱 정가
  /// 자릿수로 막으면 한 자리 더 치는 순간 글자가 사라져, 넘겼다는 것도
  /// 넘길 수 없다는 것도 알 수 없다. 넘긴 값은 문구로 알린다.
  int get maxDigits => faceValue.toString().length + 1;

  @override
  bool operator ==(Object other) =>
      other is ListingPrice &&
      other.value == value &&
      other.faceValue == faceValue;

  @override
  int get hashCode => Object.hash(value, faceValue);
}
