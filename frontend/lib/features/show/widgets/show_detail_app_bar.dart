import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 공연 상세 상단 바 — 뒤로가기 · 제목 · 찜. 시안의 공유 버튼은 공유할 링크가
/// 아직 없어 달지 않았다. 아이콘만 있는 버튼이라 [IconButton.tooltip] 으로 이름을
/// 준다. 툴팁은 스크린 리더에 읽히므로 `Semantics` 를 따로 두르지 않아도 된다.
class ShowDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShowDetailAppBar({
    super.key,
    required this.isFavorite,
    required this.onFavoritePressed,
  });

  /// 이 공연이 찜 목록에 있는가. 채운 하트와 빈 하트로 가른다.
  final bool isFavorite;

  /// 하트를 눌렀을 때. 공연을 아직 못 받았으면 null 이라 눌리지 않는다 —
  /// 무엇을 찜할지 모르는 상태다.
  final VoidCallback? onFavoritePressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(ShowDetailStrings.appBarTitle),
      actions: [
        IconButton(
          onPressed: onFavoritePressed,
          tooltip: isFavorite
              ? ShowDetailStrings.unfavoriteAction
              : ShowDetailStrings.favoriteAction,
          color: isFavorite ? AppColors.primary : null,
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
        ),
      ],
    );
  }
}
