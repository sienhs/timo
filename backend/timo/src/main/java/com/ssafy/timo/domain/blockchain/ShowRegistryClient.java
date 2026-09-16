package com.ssafy.timo.domain.blockchain;

import com.ssafy.timo.global.config.BlockchainProperties;
import java.math.BigInteger;
import java.util.List;
import org.springframework.stereotype.Component;
import org.web3j.abi.TypeReference;
import org.web3j.abi.datatypes.Bool;
import org.web3j.abi.datatypes.Function;
import org.web3j.abi.datatypes.Utf8String;
import org.web3j.abi.datatypes.generated.Uint256;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.tx.RawTransactionManager;

/**
 * {@code ShowRegistry.sol} 호출. 등록({@code registerShow})은 {@code ORGANIZER_ROLE} 기반이라
 * admin 지갑으로 서명한다 - 실제 주최자별 개인키 서명은 필요 없다({@link Web3jConfig}의 설명 참고).
 */
@Component
public class ShowRegistryClient extends ContractClient {

    /** registerShow(uint256,uint256,uint256,uint256,string) 가 emit하는 이벤트의 정규화 시그니처. */
    private static final String SHOW_REGISTERED_EVENT =
            "ShowRegistered(uint256,address,uint256,uint256,uint256,uint256)";

    public ShowRegistryClient(Web3j web3j, RawTransactionManager adminTransactionManager, BlockchainProperties properties) {
        super(web3j, adminTransactionManager, properties.showRegistryAddress());
    }

    /**
     * 공연을 등록한다.
     *
     * @return 발급된 showId. 반환값은 영수증에 없어 {@code ShowRegistered} 이벤트 로그에서 읽는다.
     */
    public BigInteger registerShow(BigInteger facePrice, BigInteger totalSeats,
                                    long saleOpenTimeEpochSeconds, long showTimeEpochSeconds, String metadataUri) {
        TransactionReceipt receipt = sendAndWait(new Function("registerShow",
                List.of(new Uint256(facePrice), new Uint256(totalSeats),
                        new Uint256(BigInteger.valueOf(saleOpenTimeEpochSeconds)),
                        new Uint256(BigInteger.valueOf(showTimeEpochSeconds)),
                        new Utf8String(metadataUri)),
                List.of(new TypeReference<Uint256>() {})));
        return extractIndexedUint256(receipt, SHOW_REGISTERED_EVENT, 1);
    }

    public boolean isSaleOpen(BigInteger showId) {
        return call(new Function("isSaleOpen",
                List.of(new Uint256(showId)),
                List.of(new TypeReference<Bool>() {})));
    }
}
