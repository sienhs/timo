import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 환경 설정의 한 묶음. 제목 아래 테두리 카드에 줄들을 쌓고 사이에 선을 긋는다.
///
/// 카드는 마이페이지의 잔액·내역 카드와 같은 모서리를 쓴다. 다만 저쪽은
/// 브랜드색 테두리고 여기는 연회색이다 — 설정은 눈에 띄어야 할 내용이 아니라
/// 훑어 내려가며 찾는 목록이다.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SettingsMetrics.tileHorizontalPadding,
          ),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: SettingsMetrics.sectionTitleGap),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(SettingsMetrics.cardRadius),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
