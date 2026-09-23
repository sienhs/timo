import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../auth/state/auth_session_scope.dart';
import '../constants.dart';
import '../models/favorite_show.dart';
import '../state/favorite_scope.dart';

/// 공연 하트를 눌렀을 때 할 일. 검색 결과·공연 상세·찜리스트가 함께 쓴다.
/// 로그아웃 상태면 부르지 않고 안내하고, 실패하면 알린다. 아티스트 하트는
/// 기기에만 남아 이걸 쓰지 않는다.
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
