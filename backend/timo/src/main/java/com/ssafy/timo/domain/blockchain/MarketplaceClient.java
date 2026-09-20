package com.ssafy.timo.domain.blockchain;

import com.ssafy.timo.global.config.blockchain.DeployedContractAddresses;

import java.math.BigInteger;
import java.util.Collections;
import java.util.List;

import org.springframework.stereotype.Component;

import org.web3j.abi.datatypes.Address;
import org.web3j.abi.datatypes.Function;
import org.web3j.abi.datatypes.generated.Bytes32;
import org.web3j.abi.datatypes.generated.Uint256;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.tx.RawTransactionManager;

/** {@code Marketplace.sol} 호출. {@code buy}는 컨트랙트 자신의 {@code OPERATOR_ROLE} 기반이라 admin 지갑으로 서명한다. */
@Component
public class MarketplaceClient extends ContractClient {

    public MarketplaceClient(Web3j web3j, RawTransactionManager adminTransactionManager, DeployedContractAddresses addresses) {
        super(web3j, adminTransactionManager, addresses.marketplaceAddress());
    }

    /**
     * 양도 체결. {@code TicketNFT.settleTransfer}와 {@code TicketVault.settleTransfer}를 한 트랜잭션으로
     * 묶어 호출하므로, 소유권 이전과 대금 정산 중 하나만 성공하는 상태가 없다.
     *
     * @return 체결 트랜잭션 해시
     */
    public String buy(BigInteger tokenId, String buyerAddress, byte[] tradeId) {
        TransactionReceipt receipt = sendAndWait(new Function("buy",
                List.of(new Uint256(tokenId), new Address(buyerAddress), new Bytes32(tradeId)),
                Collections.emptyList()));
        return receipt.getTransactionHash();
    }
}
