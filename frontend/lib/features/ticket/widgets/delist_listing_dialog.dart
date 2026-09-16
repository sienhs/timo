import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../resale/models/my_trade.dart';
import '../constants.dart';
import 'ticket_confirm_dialog.dart';

/// 양도 등록 취소(매물 내리기) 확인 팝업.
///
/// 내리는 것은 되돌릴 수 있지만(다시 올리면 된다) 그 사이 사려던 사람은 놓친다.
/// 그래서 예매 취소와 같은 틀로 한 번 묻고, 무엇을 내리는지(공연·좌석)와 얼마에
/// 올려 뒀는지를 함께 보여준다. 틀과 버튼 모양은 [showTicketConfirmDialog] 가 정한다.
///
/// 내리기로 했으면 true, 아니면 false.
Future<bool> showDelistListingDialog(
  BuildContext context, {
  required MyTrade trade,
}) => showTicketConfirmDialog(
  context,
  title: TicketStrings.delistConfirmTitle,
  summary: (
    title: trade.concertTitle,
    seat: trade.seatLabel,
    amount: TicketStrings.listedPriceLabel(formatMsr(trade.price)),
  ),
  body: TicketStrings.delistConfirmBody,
  agreeLabel: TicketStrings.delistConfirmAgree,
);
