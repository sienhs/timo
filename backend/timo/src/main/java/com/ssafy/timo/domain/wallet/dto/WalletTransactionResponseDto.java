package com.ssafy.timo.domain.wallet.dto;

import com.ssafy.timo.domain.wallet.entity.WalletTransaction;
import java.time.LocalDateTime;

public record WalletTransactionResponseDto(
        String title,
        long amount,
        long balanceAfter,
        LocalDateTime occurredAt,
        String source
) {
    public static WalletTransactionResponseDto from(WalletTransaction transaction) {
        return new WalletTransactionResponseDto(
                transaction.getTitle(),
                transaction.getAmount().longValueExact(),
                transaction.getBalanceAfter().longValueExact(),
                transaction.getCreatedAt(),
                transaction.getSource());
    }
}
