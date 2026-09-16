package com.ssafy.timo.domain.blockchain;

import com.ssafy.timo.global.config.DeployedContractAddresses;
import java.math.BigInteger;
import java.util.Collections;
import java.util.List;
import org.springframework.stereotype.Component;
import org.web3j.abi.TypeReference;
import org.web3j.abi.datatypes.Address;
import org.web3j.abi.datatypes.Function;
import org.web3j.abi.datatypes.generated.Bytes32;
import org.web3j.abi.datatypes.generated.Uint256;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.tx.RawTransactionManager;

/**
 * {@code TicketNFT.sol} 호출. 발행({@code mintTicket})은 {@code ORGANIZER_ROLE} 기반이라
 * admin 지갑으로 서명한다.
 */
@Component
public class TicketNftClient extends ContractClient {

    public TicketNftClient(Web3j web3j, RawTransactionManager adminTransactionManager, DeployedContractAddresses addresses) {
        super(web3j, adminTransactionManager, addresses.ticketNftAddress());
    }

    /**
     * 좌석 하나를 발행한다. facePrice는 {@code ShowRegistry}에서 컨트랙트가 직접 읽으므로 여기서
     * 넘기지 않는다.
     *
     * @return 발급된 tokenId와 트랜잭션 해시. tokenId는 영수증에 없어 {@code seatTokenId} 매핑을 다시 읽어 얻는다.
     */
    public MintResult mintTicket(String toAddress, BigInteger showId, BigInteger seatId) {
        TransactionReceipt receipt = sendAndWait(new Function("mintTicket",
                List.of(new Address(toAddress), new Uint256(showId), new Uint256(seatId)),
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

    private BigInteger seatTokenId(BigInteger showId, BigInteger seatId) {
        byte[] key = call(new Function("seatKey",
                List.of(new Uint256(showId), new Uint256(seatId)),
                List.of(new TypeReference<Bytes32>() {})));
        return call(new Function("seatTokenId",
                List.of(new Bytes32(key)),
                List.of(new TypeReference<Uint256>() {})));
    }
}
