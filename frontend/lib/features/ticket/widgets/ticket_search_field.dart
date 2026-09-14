import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 목록 위 검색 칸. 공연명으로 카드를 걸러 낸다.
///
/// 서버에 보내지 않고 이미 받아 둔 목록에서 거른다. 내 티켓은 많아야 수십
/// 장이라 앱에서 거르는 편이 빠르고, 글자마다 요청을 보낼 일도 없다. 그래서
/// 제출을 기다리지 않고 글자마다 바로 걸러 준다 — 홈 검색과 다른 점이다.
class TicketSearchField extends StatelessWidget {
  const TicketSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: TicketStrings.searchHint,
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: AppColors.textSecondary,
        ),
        // 값이 있을 때만 지우기 버튼을 낸다. 빈 칸에 X 가 있으면 누를 것이 없다.
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
