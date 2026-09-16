import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 목록 위 검색 칸. 공연명으로 카드를 걸러 낸다.
///
/// 서버에 보내지 않고 이미 받아 둔 목록에서 거른다. 마켓의 공연 목록도 내
/// 티켓 목록도 한 번에 다 받으므로 앱에서 거르는 편이 빠르고, 글자마다 요청을
/// 보낼 일도 없다.
///
/// 내 티켓의 `TicketSearchField` 와 생김새가 같다. 지금은 문구가 다를 뿐이라
/// 합칠 수도 있지만, 두 화면이 같은 이유로 바뀔지(검색을 서버로 옮긴다면 내
/// 티켓은 그대로고 마켓만 바뀐다) 아직 알 수 없어 각자 둔다. 세 번째 화면이
/// 같은 칸을 쓰게 되면 `core/widgets` 로 올린다.
class ResaleSearchField extends StatelessWidget {
  const ResaleSearchField({
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
        hintText: ResaleStrings.searchHint,
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
