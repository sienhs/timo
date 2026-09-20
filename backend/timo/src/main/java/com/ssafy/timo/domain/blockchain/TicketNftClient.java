package com.ssafy.timo.domain.blockchain;

import com.ssafy.timo.global.config.blockchain.DeployedContractAddresses;

import java.math.BigInteger;
import java.util.Collections;
import java.util.List;

import org.springframework.stereotype.Component;

import org.web3j.abi.TypeReference;
import org.web3j.abi.datatypes.Address;
import org.web3j.abi.datatypes.Function;
import org.web3j.abi.datatypes.generated.Bytes32;
import org.web3j.abi.datatypes.generated.Uint256;
import org.web3j.abi.datatypes.generated.Uint8;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.tx.RawTransactionManager;

/**
 * {@code TicketNFT.sol} 호출. 발행({@code mintTicket})은 {@code ORGANIZER_ROLE} 기반이라 admin 지갑으로 서명한다.
 */
@Component
public class TicketNftClient extends ContractClient {

    public TicketNftClient(Web3j web3j, RawTransactionManager adminTransactionManager, DeployedContractAddresses addresses) {
        super(web3j, adminTransactionManager, addresses.ticketNftAddress());
    }

    /** 좌석 하나를 발행한다. facePrice는 안 넘긴다 - 컨트랙트가 sectionIndex로 ShowRegistry 정가를 직접 읽어 위조 여지가 없다. */
    public MintResult mintTicket(String toAddress, BigInteger showId, BigInteger seatId, int sectionIndex) {
        TransactionReceipt receipt = sendAndWait(new Function("mintTicket",
                List.of(new Address(toAddress), new Uint256(showId), new Uint256(seatId), new Uint8(sectionIndex)),
                Collections.emptyList()));
        return new MintResult(seatTokenId(showId, seatId), receipt.getTransactionHash());
    }

    public String ownerOf(BigInteger tokenId) {
        return call(new Function("ownerOf",
                List.of(new Uint256(tokenId)),
                List.of(new TypeReference<Address>() {})));
    }

    /** 예매 취소 등으로 좌석을 회수한다. {@code OWNED}에서만 성립하고, 소유권은 custodyVault로 옮겨간다. */
    public void revoke(BigInteger tokenId) {
        sendAndWait(new Function("revoke", List.of(new Uint256(tokenId)), Collections.emptyList()));
    }

    /** 매물을 연다({@code OWNED} → {@code LISTED}). {@code ownerAddress}는 컨트랙트가 {@code ownerOf}와 재대조한다. */
    public void listForTransferFor(BigInteger tokenId, String ownerAddress, BigInteger askPrice) {
        sendAndWait(new Function("listForTransferFor",
                List.of(new Uint256(tokenId), new Address(ownerAddress), new Uint256(askPrice)),
                Collections.emptyList()));
    }

    /** 매물을 닫는다({@code LISTED} → {@code OWNED}). */
    public void delistFor(BigInteger tokenId, String ownerAddress) {
        sendAndWait(new Function("delistFor",
                List.of(new Uint256(tokenId), new Address(ownerAddress)),
                Collections.emptyList()));
    }

    /**
     * 게이트 입장 처리. LISTED(양도 등록 중) 티켓은 거절한다. admin 지갑에 GATE_ROLE 필요(deploy.ts가 부여).
     * 게이트 응답 경로에서 기다리지 않는다 - 입장 원본은 DB이고 체인은 그 기록일 뿐이다.
     */
    public void markUsed(BigInteger tokenId) {
        sendAndWait(new Function("markUsed", List.of(new Uint256(tokenId)), Collections.emptyList()));
    }

    private BigInteger seatTokenId(BigInteger showId, BigInteger seatId) {
        byte[] key = call(new Function("seatKey",
                List.of(new Uint256(showId), new Uint256(seatId)),
                List.of(new TypeReference<Bytes32>() {})));
        return call(new Function("seatTokenId",
                List.of(new Bytes32(key)),
                List.of(new TypeReference<Uint256>() {})));
    }
}
