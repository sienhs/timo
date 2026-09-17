import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/listing_price.dart';
import 'listing_price_editor.dart';
import 'resale_bottom_bar.dart';

/// 올라가 있는 매물의 등록가를 고치는 바텀시트. 내 티켓의 양도 목록 탭이 연다.
///
/// 판매가 입력 자리([ListingPriceEditor])와 상한 규칙([ListingPrice])은 등록
/// 화면과 같은 것을 쓴다 — 서버도 등록과 수정에 같은 규칙(등록 시점 정가
/// 이하)을 대므로, 화면이 두 벌이면 한쪽만 고쳐질 때 어긋난다.
///
/// 서버에 보내지는 않는다. 새 가격을 돌려주면 화면이 요청을 보내고 목록을
/// 다시 받는다(등록 취소 팝업과 같은 역할 분담). 그대로 두거나 값을 안 바꾸고
/// 닫으면 null 이다.
Future<int?> showListingPriceSheet(
  BuildContext context, {
  required int currentPrice,
  required int faceValue,
}) {
  return showModalBottomSheet<int>(
    context: context,
    // 키보드가 올라오면 시트가 그만큼 밀려 올라가야 입력칸이 가리지 않는다.
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) =>
        _ListingPriceSheet(currentPrice: currentPrice, faceValue: faceValue),
  );
}

class _ListingPriceSheet extends StatefulWidget {
  const _ListingPriceSheet({
    required this.currentPrice,
    required this.faceValue,
  });

  final int currentPrice;
  final int faceValue;

  @override
  State<_ListingPriceSheet> createState() => _ListingPriceSheetState();
}

class _ListingPriceSheetState extends State<_ListingPriceSheet> {
  /// 처음 값은 지금 등록가다. 빈 칸으로 시작하면 얼마였는지 모른 채 새 값을
  /// 적게 된다.
  late final _controller = TextEditingController(
    text: formatThousands(widget.currentPrice),
  );

  ListingPrice get _price =>
      ListingPrice.parse(_controller.text, faceValue: widget.faceValue);

  /// 같은 값으로는 보내지 않는다. 서버가 거절하지는 않지만 아무것도 안 바뀌는
  /// 요청이라, 버튼을 잠가 "바꾼 게 없다" 를 미리 알린다.
  bool get _canSubmit =>
      _price.canSubmit && _price.value != widget.currentPrice;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPriceChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onPriceChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      // 키보드 높이만큼 아래를 띄운다([isScrollControlled] 와 함께 쓴다).
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 손잡이. 이 시트가 끌어 내려 닫히는 것임을 알린다.
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ResaleMetrics.horizontalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ResaleStrings.editPriceTitle,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ResaleStrings.editPriceCurrent(
                    formatMsr(widget.currentPrice),
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ListingPriceEditor(
                  controller: _controller,
                  price: _price,
                  onSliderChanged: (value) =>
                      _controller.text = formatThousands(value),
                ),
              ],
            ),
          ),
          ResaleBottomBar(
            child: ResaleActionButton(
              label: ResaleStrings.editPriceSubmit,
              onPressed: _canSubmit
                  ? () => Navigator.pop(context, _price.value)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
