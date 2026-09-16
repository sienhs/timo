package com.ssafy.timo.domain.blockchain;

import java.math.BigInteger;

/** {@link TicketNftClient#mintTicket} 결과 - 발급된 tokenId와 그 트랜잭션 해시. */
public record MintResult(BigInteger tokenId, String transactionHash) {
}
