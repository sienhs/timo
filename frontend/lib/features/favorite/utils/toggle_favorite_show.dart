import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../auth/state/auth_session_scope.dart';
import '../constants.dart';
import '../models/favorite_show.dart';
import '../state/favorite_scope.dart';

/// 공연 하트를 눌렀을 때 할 일. 검색 결과·공연 상세·찜리스트가 함께 쓴다.
///
/// 세 화면이 같은 일을 해야 해서 한곳에 둔다. 공연 찜은 서버에 남으므로
/// (1) 로그아웃 상태면 부르지 않고 안내하고, (2) 실패하면 알린다. 화면마다
/// 적으면 로그인 안내를 빠뜨린 화면에서만 401 이 나거나, 실패한 하트가 채워진
/// 채 남는다.
///
/// 아티스트 하트는 이걸 쓰지 않는다. 기기에만 남아 로그인도 필요 없고 실패할
/// 일도 없다.
Future<void> toggleFavoriteShow(BuildContext context, FavoriteShow show) async {
  if (!(AuthSessionScope.maybeRead(context)?.isLoggedIn ?? false)) {
    showInfoSnackBar(context, FavoriteStrings.loginRequired);
    return;
  }

  try {
    await FavoriteScope.read(context).toggleShow(show);
  } on ApiException catch (e) {
    if (context.mounted) showErrorSnackBar(context, e.message);
  } catch (_) {
    if (context.mounted) {
      showErrorSnackBar(context, FavoriteStrings.toggleFailed);
    }
  }
}
