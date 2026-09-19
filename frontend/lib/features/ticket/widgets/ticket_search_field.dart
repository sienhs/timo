import 'package:flutter/material.dart';
import '../../../core/widgets/app_search_field.dart';
import '../constants.dart';

/// 목록 검색은 입력과 지우기 즉시 반영한다.
class TicketSearchField extends StatelessWidget {
  const TicketSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => AppSearchField(
    controller: controller,
    hintText: TicketStrings.searchHint,
    onChanged: onChanged,
  );
}
