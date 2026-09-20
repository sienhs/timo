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
import org.web3j.protocol.Web3j;
import org.web3j.tx.RawTransactionManager;

/**
 * {@code TicketVault.sol}의 "코인" 원장 호출. 전부 {@code OPERATOR_ROLE}/{@code MARKETPLACE_ROLE}
 * 기반이라 admin 지갑 하나로 서명한다 - 사용자 개인 키가 필요 없다.
 */
@Component
public class TicketVaultClient extends ContractClient {

    public TicketVaultClient(Web3j web3j, RawTransactionManager adminTransactionManager, DeployedContractAddresses addresses) {
        super(web3j, adminTransactionManager, addresses.ticketVaultAddress());
    }

    /** PG 충전을 온체인 잔액으로 미러링한다. */
    public void deposit(String userAddress, BigInteger amount, byte[] refId) {
        sendAndWait(new Function("deposit",
                List.of(new Address(userAddress), new Uint256(amount), new Bytes32(refId)),
                Collections.emptyList()));
    }

    /** 구매자 잔액에서 정가를 차감해 주최자 잔액으로 적립한다(1차 판매). */
    public void chargeForBooking(String buyerAddress, String organizerAddress, BigInteger amount, byte[] orderId) {
        sendAndWait(new Function("chargeForBooking",
                List.of(new Address(buyerAddress), new Address(organizerAddress), new Uint256(amount), new Bytes32(orderId)),
                Collections.emptyList()));
    }

    /** 취소·민팅 실패 보상 등으로, 앞서 chargeForBooking이 적립했던 주최사 잔액에서 그만큼 되찾아 구매자에게 돌려준다. */
    public void refund(String userAddress, String organizerAddress, BigInteger amount, byte[] refId) {
        sendAndWait(new Function("refund",
                List.of(new Address(userAddress), new Address(organizerAddress), new Uint256(amount), new Bytes32(refId)),
                Collections.emptyList()));
    }

    public BigInteger balanceOf(String address) {
        return call(new Function("balanceOf",
                List.of(new Address(address)),
                List.of(new TypeReference<Uint256>() {})));
    }
}
