package com.ssafy.timo.domain.wallet.dto;

import java.util.List;

/** 내 지갑. 잔액과 최근 거래 내역을 함께 든다. */
public record WalletSummaryResponseDto(
        long balance,
        List<WalletTransactionResponseDto> transactions
) {
}
