import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/listing_price.dart';
import '../utils/price_input_formatter.dart';

/// 판매가를 정하는 자리. 안내 한 줄 + 입력칸 + 슬라이더.
///
/// 값은 화면이 아니라 [controller] 하나가 들고 있다. 슬라이더를 움직이면
/// 입력칸 글자를 고쳐 쓰는 방식이라, 화면 어디에도 같은 금액이 두 벌로 남지
/// 않는다(충전 화면의 금액 칸과 같은 방식이다).
///
/// 정가를 넘기면 안내 문구·테두리·슬라이더가 함께 붉어지고 등록 버튼이 잠긴다.
/// 잠그는 판단은 [ListingPrice] 가 하고 이 위젯은 그 결과만 그린다.
class ListingPriceEditor extends StatelessWidget {
  const ListingPriceEditor({
    super.key,
    required this.controller,
    required this.price,
    required this.onSliderChanged,
  });

  final TextEditingController controller;
  final ListingPrice price;

  /// 슬라이더를 움직였을 때의 금액. 화면이 입력칸에 옮겨 적는다.
  final ValueChanged<int> onSliderChanged;

  @override
  Widget build(BuildContext context) {
    final error = price.errorMessage;
    final accentColor = error == null ? AppColors.primary : AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          ResaleStrings.priceSectionTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          error ?? ResaleStrings.priceHint,
          style: TextStyle(
            fontSize: 12,
            color: error == null ? AppColors.textSecondary : AppColors.accent,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [PriceInputFormatter(maxDigits: price.maxDigits)],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: ResaleStrings.priceFieldLabel,
            // 라벨은 화면 읽기 프로그램용이다. 시안에는 칸 안에 금액만 있다.
            floatingLabelBehavior: FloatingLabelBehavior.never,
            suffixText: ResaleStrings.priceUnit,
            suffixStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            enabledBorder: _border(
              error == null ? AppColors.border : AppColors.accent,
            ),
            focusedBorder: _border(accentColor),
            border: _border(AppColors.border),
          ),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accentColor,
            thumbColor: accentColor,
            inactiveTrackColor: AppColors.border,
            // 값이 글자로도 바로 위 칸에 있어 말풍선까지 띄우면 겹친다.
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: price.ratio,
            label: formatMsr(price.value),
            semanticFormatterCallback: (_) => formatMsr(price.value),
            onChanged: (ratio) =>
                onSliderChanged(_roundToStep(ratio * price.faceValue)),
          ),
        ),
        Row(
          children: [
            const Text(
              ResaleStrings.sliderMinLabel,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const Spacer(),
            Text(
              ResaleStrings.faceValueOf(formatMsr(price.faceValue)),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 슬라이더가 만드는 금액은 백 원 단위로 끊는다. 손가락으로 1원 단위를 맞출
  /// 수는 없고, 끊지 않으면 `176,384원` 같은 값이 나온다.
  static int _roundToStep(double value) => (value / _step).round() * _step;

  static const _step = 100;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color),
  );
}
