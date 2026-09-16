import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import 'my_page_card.dart';

/// 내 버섯 카드. 잔액과 충전 입구다. (클래스 이름의 Mushroom 은 코인의 영문
/// 이름으로 남겨 뒀다 — 화면 문구는 전부 '버섯' 이다.)
///
/// 잔액만 받아 그린다. 어디서 온 값인지(서버·목업)는 모른다.
class MushroomBalanceCard extends StatelessWidget {
  const MushroomBalanceCard({
    super.key,
    required this.balance,
    this.onChargePressed,
  });

  /// 사용 가능 잔액(MSR).
  final int balance;

  /// 충전하기 버튼. null 이면 버튼 없이 잔액만 그린다 — 충전 화면은 이미
  /// 충전하러 들어온 자리라 카드 안에 또 입구를 둘 이유가 없다(시안도 없다).
  final VoidCallback? onChargePressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MyPageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _WalletMark(),
              const SizedBox(width: MyPageMetrics.walletTitleGap),
              Expanded(
                child: Text(
                  MyPageStrings.walletTitle,
                  style: textTheme.titleSmall,
                ),
              ),
              Text(MyPageStrings.exchangeRate, style: textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: MyPageMetrics.balanceTopGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 잔액이 길어지면(천만 단위) 줄을 넘치지 않고 글자를 줄인다. 금액이
              // 잘려 보이는 것보다 작게 다 보이는 쪽이 낫다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    formatThousands(balance),
                    style: textTheme.headlineSmall?.copyWith(
                      fontSize: MyPageMetrics.balanceFontSize,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MyPageMetrics.balanceUnitGap),
              Text(
                MyPageStrings.currencyUnit,
                // 흰 배경 위 작은 글자라 [AppColors.primary] 는 대비가 모자란다.
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryPressed,
                ),
              ),
            ],
          ),
          if (onChargePressed != null) ...[
            const SizedBox(height: MyPageMetrics.chargeButtonTopGap),
            SizedBox(
              width: double.infinity,
              height: MyPageMetrics.chargeButtonHeight,
              child: FilledButton(
                onPressed: onChargePressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  textStyle: textTheme.labelLarge,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      MyPageMetrics.chargeButtonRadius,
                    ),
                  ),
                ),
                child: const Text(MyPageStrings.charge),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 카드 제목 앞의 동그란 `M` 마크. 코인 아이콘 에셋이 나오면 이미지로 바꾼다.
class _WalletMark extends StatelessWidget {
  const _WalletMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MyPageMetrics.walletIconSize,
      height: MyPageMetrics.walletIconSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        'M',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
