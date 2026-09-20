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
 * {@code TicketNFT.sol} 호출. 발행({@code mintTicket})은 {@code ORGANIZER_ROLE} 기반이라
 * admin 지갑으로 서명한다.
 */
@Component
public class TicketNftClient extends ContractClient {

    public TicketNftClient(Web3j web3j, RawTransactionManager adminTransactionManager, DeployedContractAddresses addresses) {
        super(web3j, adminTransactionManager, addresses.ticketNftAddress());
    }

    /**
     * 좌석 하나를 발행한다. facePrice는 넘기지 않는다 - {@code ShowRegistry}에 이미 등록된
     * {@code sectionIndex}(0-4)번 구역 가격을 컨트랙트가 직접 읽는다. 호출자가 고를 수 있는 건
     * "어느 구역이냐"뿐이고, 그 구역의 가격 자체를 조작할 방법은 없다.
     *
     * @return 발급된 tokenId와 트랜잭션 해시. tokenId는 영수증에 없어 {@code seatTokenId} 매핑을 다시 읽어 얻는다.
     */
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

    /**
     * 게이트 입장 처리. 온체인도 {@code OWNED}에서만 성립하고, 양도 등록 중({@code LISTED})인
     * 티켓은 거절한다 - 팔려고 내놓은 표로 입장시키는 것은 말이 안 되기 때문이다.
     *
     * <p>admin 지갑에 {@code GATE_ROLE}이 있어야 한다 - 배포 스크립트({@code deploy.ts})가
     * {@code ORGANIZER_ROLE}·{@code OPERATOR_ROLE}과 함께 부여한다. 그 grant 없이 뜬 노드라면
     * 여기서 AccessControl 로 되돌려진다.
     *
     * <p>게이트 응답 경로에서 이 호출을 기다리면 안 된다. 입장 줄은 1인당 1초 싸움이라 체인 확정을
     * 기다릴 여유가 없다. 입장했다는 사실의 원본은 DB이고 체인은 그 기록이다.
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
