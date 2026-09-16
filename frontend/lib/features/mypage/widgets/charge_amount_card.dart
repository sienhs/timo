import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/charge_amount.dart';
import '../utils/charge_amount_input_formatter.dart';
import 'my_page_card.dart';

/// 충전할 금액 카드. 금액 칸 여섯 개 · 직접 입력 · 요약 두 줄이 한 카드에 있다.
///
/// 상태는 들지 않는다. 금액은 [controller] 하나에만 있고([amount] 는 그걸
/// 해석한 값), 칸을 누르면 [onPresetSelected] 로 알린다. 화면이 컨트롤러에
/// 값을 써 주면 고른 칸 표시와 요약이 함께 따라온다 — 고른 칸과 입력칸의 값이
/// 서로 어긋날 자리가 없다.
class ChargeAmountCard extends StatelessWidget {
  const ChargeAmountCard({
    super.key,
    required this.controller,
    required this.amount,
    required this.balance,
    required this.onPresetSelected,
  });

  final TextEditingController controller;

  /// 지금 입력된 금액. [controller] 의 글자를 해석한 값이다.
  final ChargeAmount amount;

  /// 현재 잔액(MSR). 아직 못 받았거나 조회에 실패했으면 null 이고, 그때는
  /// 추가 후 잔액 줄을 비워 둔다 — 잔액 카드가 이미 실패를 말하고 있어 같은
  /// 실패를 두 번 알리지 않는다.
  final int? balance;

  final ValueChanged<int> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentBalance = balance;

    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(MyPageStrings.chargeAmountTitle, style: textTheme.titleSmall),
          const SizedBox(height: MyPageMetrics.chargeGuideTopGap),
          Text(MyPageStrings.chargeAmountGuide, style: textTheme.labelMedium),
          const SizedBox(height: MyPageMetrics.presetGridTopGap),
          _PresetGrid(selected: amount.value, onSelected: onPresetSelected),
          const SizedBox(height: MyPageMetrics.directInputTopGap),
          Text(MyPageStrings.directInput, style: textTheme.labelMedium),
          const SizedBox(height: MyPageMetrics.directInputLabelGap),
          _AmountField(controller: controller, errorText: amount.errorMessage),
          const SizedBox(height: MyPageMetrics.chargeSummaryTopGap),
          const Divider(),
          const SizedBox(height: MyPageMetrics.chargeSummaryTopGap),
          _SummaryRow(
            label: MyPageStrings.chargeAmountLabel,
            value: amount.value,
          ),
          const SizedBox(height: MyPageMetrics.chargeSummaryRowGap),
          _SummaryRow(
            label: MyPageStrings.balanceAfterCharge,
            value: currentBalance == null
                ? null
                : currentBalance + amount.value,
            highlighted: true,
          ),
        ],
      ),
    );
  }
}

/// 금액 칸 격자. 시안대로 2열로 접는다.
class _PresetGrid extends StatelessWidget {
  const _PresetGrid({required this.selected, required this.onSelected});

  /// 지금 입력된 금액. 같은 값의 칸이 고른 것으로 보인다. 직접 입력한 금액이
  /// 우연히 칸과 같아도 마찬가지다 — 사용자가 보기에 같은 금액이다.
  final int selected;

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (
      var start = 0;
      start < ChargeAmount.presets.length;
      start += MyPageMetrics.presetColumns
    ) {
      final values = ChargeAmount.presets
          .skip(start)
          .take(MyPageMetrics.presetColumns)
          .toList();
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: MyPageMetrics.presetGap));
      }
      rows.add(
        Row(
          children: [
            for (var column = 0; column < values.length; column++) ...[
              if (column > 0) const SizedBox(width: MyPageMetrics.presetGap),
              Expanded(
                child: _PresetOption(
                  value: values[column],
                  selected: values[column] == selected,
                  onPressed: () => onSelected(values[column]),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

/// 금액 칸 하나. 고르면 테두리·배경이 바뀌고 오른쪽에 체크가 붙는다.
///
/// 체크와 `Semantics(selected:)` 를 함께 두는 이유: 색만으로 고른 칸을 가르면
/// 색을 못 가리는 사람과 화면 낭독기 사용자가 무엇을 골랐는지 알 수 없다.
class _PresetOption extends StatelessWidget {
  const _PresetOption({
    required this.value,
    required this.selected,
    required this.onPressed,
  });

  final int value;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // 고름 표시와 버튼을 한 노드로 합친다. 합치지 않으면 화면 낭독기가 버튼과
    // 고름 여부를 따로 읽어, 무엇이 골라졌는지가 버튼 이름과 떨어진다.
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        // 고를 때 색과 체크가 한 번에 튀지 않고 이어서 바뀐다. 0(안 고름)과
        // 1(고름) 사이를 오가는 값 하나로 테두리·배경·체크 자리를 함께 움직여,
        // 셋의 타이밍이 어긋날 자리가 없다.
        //
        // 애니메이션을 끈 기기(접근성 설정)에서는 시간을 0 으로 둬 즉시 바뀐다.
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: selected ? 1 : 0),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : MyPageMetrics.presetSelectTransition,
          curve: Curves.easeOut,
          builder: (context, progress, _) => OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(MyPageMetrics.presetHeight),
              backgroundColor: Color.lerp(
                AppColors.surface,
                AppColors.seatAvailable,
                progress,
              ),
              side: BorderSide(
                color: Color.lerp(
                  AppColors.border,
                  AppColors.primary,
                  progress,
                )!,
                width: 1 + (MyPageMetrics.cardBorderWidth - 1) * progress,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MyPageMetrics.presetRadius),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: MyPageMetrics.presetHorizontalPadding,
              ),
            ),
            // 금액과 체크를 한 덩어리로 가운데 정렬한다. 체크 자리를 미리 비워
            // 두고 금액만 가운데 두면, 고른 칸에서 체크가 홀로 오른쪽 끝에
            // 떨어져 금액과 상관없는 표시처럼 보인다.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      MyPageStrings.withUnit(formatThousands(value)),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                // 체크가 차지하는 폭이 0 에서 커지므로, 가운데 정렬된 금액이
                // 그만큼 왼쪽으로 밀리며 자리를 내준다.
                if (progress > 0)
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: progress,
                      child: Opacity(
                        opacity: progress,
                        child: const Padding(
                          padding: EdgeInsets.only(
                            left: MyPageMetrics.presetCheckGap,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: MyPageMetrics.presetCheckSize,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 직접 입력 칸. 숫자만 받고 치는 대로 쉼표가 붙는다.
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.errorText});

  final TextEditingController controller;

  /// 한도를 벗어났을 때의 안내. 없으면 null.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: MyPageStrings.directInput,
      textField: true,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.done,
        inputFormatters: const [ChargeAmountInputFormatter()],
        style: Theme.of(context).textTheme.titleSmall,
        decoration: InputDecoration(
          hintText: MyPageStrings.chargeAmountHint,
          errorText: errorText,
          suffixIcon: const _UnitSuffix(),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
      ),
    );
  }
}

/// 입력칸 오른쪽 끝의 세로선과 단위.
class _UnitSuffix extends StatelessWidget {
  const _UnitSuffix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MyPageMetrics.unitDividerGap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 1,
            height: MyPageMetrics.unitDividerHeight,
            color: AppColors.border,
          ),
          const SizedBox(width: MyPageMetrics.unitDividerGap),
          Text(
            MyPageStrings.currencyUnit,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// 요약 한 줄. 라벨은 왼쪽, 금액은 오른쪽.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;

  /// 금액(MSR). null 이면 잔액을 아직 모른다는 뜻이라 오른쪽을 비워 둔다.
  final int? value;

  /// 브랜드색으로 강조할지. 추가 후 잔액만 강조한다.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final amount = value;
    return Row(
      children: [
        Text(label, style: textTheme.bodyMedium),
        const Spacer(),
        if (amount != null)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                MyPageStrings.withUnit(formatThousands(amount)),
                style: highlighted
                    // 흰 배경 위 작은 글자라 primary 는 대비가 모자란다.
                    ? textTheme.titleSmall?.copyWith(
                        color: AppColors.primaryPressed,
                      )
                    : textTheme.titleSmall,
              ),
            ),
          ),
      ],
    );
  }
}
