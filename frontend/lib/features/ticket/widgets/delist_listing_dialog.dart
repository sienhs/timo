import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';
import 'ticket_confirm_dialog.dart';

/// 양도 등록 취소(매물 내리기) 확인 팝업. 예매 취소와 같은 틀로 무엇을 내리는지
/// (공연·좌석)와 등록가를 함께 보여준다. 모델 대신 찍을 값만 받는다 — 내 티켓은
/// 거래를, 양도마켓은 매물을 들고 있어 부르는 자리마다 모델이 다르다. 내리면 true.
Future<bool> showDelistListingDialog(
  BuildContext context, {
  required String concertTitle,
  required String seatLabel,
  required int price,
}) => showTicketConfirmDialog(
  context,
  title: TicketStrings.delistConfirmTitle,
  summary: (
    title: concertTitle,
    seat: seatLabel,
    amount: TicketStrings.listedPriceLabel(formatMsr(price)),
  ),
  body: TicketStrings.delistConfirmBody,
  agreeLabel: TicketStrings.delistConfirmAgree,
);
