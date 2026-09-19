import 'package:flutter/material.dart';
import '../../../core/widgets/app_search_field.dart';
import '../constants.dart';

/// 공연 검색은 제출할 때 실행하며, 지우면 검색 전 상태로 돌아간다.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onCleared,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => AppSearchField(
    controller: controller,
    hintText: HomeStrings.searchHint,
    clearLabel: HomeStrings.clearSearch,
    onSubmitted: onSubmitted,
    onCleared: onCleared,
    autofocus: autofocus,
  );
}
