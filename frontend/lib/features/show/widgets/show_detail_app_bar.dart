import 'package:flutter/material.dart';

import '../constants.dart';

/// 공연 상세 상단 바 — 뒤로가기 · 제목 · 찜.
///
/// 시안에는 공유 버튼도 있었으나 달지 않았다. 공유할 링크(딥링크·웹 상세)가
/// 아직 없어서, 눌러도 '준비 중' 안내밖에 띄울 것이 없다. 링크가 생기면
/// 그때 붙인다.
///
/// 아이콘만 있는 버튼이라 [IconButton.tooltip] 으로 이름을 준다. 툴팁은
/// 스크린 리더에 그대로 읽히므로 `Semantics` 를 따로 두르지 않아도 된다.
class ShowDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShowDetailAppBar({super.key, required this.onFavoritePressed});

  final VoidCallback onFavoritePressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(ShowDetailStrings.appBarTitle),
      actions: [
        IconButton(
          onPressed: onFavoritePressed,
          tooltip: ShowDetailStrings.favoriteAction,
          icon: const Icon(Icons.favorite_border),
        ),
      ],
    );
  }
}
