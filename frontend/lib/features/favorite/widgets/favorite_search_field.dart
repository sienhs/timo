import 'package:flutter/material.dart';
import '../../../core/widgets/app_search_field.dart';
import '../constants.dart';

/// 화면의 컨트롤러 구독으로 찜 목록을 즉시 필터링한다.
class FavoriteSearchField extends StatelessWidget {
  const FavoriteSearchField({
    super.key,
    required this.controller,
    required this.hintText,
  });
  final TextEditingController controller;
  final String hintText;
  @override
  Widget build(BuildContext context) => AppSearchField(
    controller: controller,
    hintText: hintText,
    clearLabel: FavoriteStrings.clearSearch,
  );
}
