package com.ssafy.timo.domain.blockchain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.List;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.web3j.abi.FunctionEncoder;
import org.web3j.abi.FunctionReturnDecoder;
import org.web3j.abi.TypeReference;
import org.web3j.abi.datatypes.Address;
import org.web3j.abi.datatypes.Bool;
import org.web3j.abi.datatypes.Function;
import org.web3j.abi.datatypes.Type;
import org.web3j.abi.datatypes.generated.Bytes32;
import org.web3j.abi.datatypes.generated.Uint256;
import org.web3j.crypto.Credentials;
import org.web3j.crypto.Hash;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.DefaultBlockParameterName;
import org.web3j.protocol.core.methods.request.Transaction;
import org.web3j.protocol.core.methods.response.EthCall;
import org.web3j.protocol.core.methods.response.EthSendTransaction;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.protocol.http.HttpService;
import org.web3j.tx.RawTransactionManager;
import org.web3j.tx.gas.DefaultGasProvider;
import org.web3j.tx.response.PollingTransactionReceiptProcessor;

/**
 * [스파이크] 백엔드(Java/web3j)가 실제로 SSAFY EC2에 올린 Hardhat 체인에 트랜잭션을 보낼 수
 * 있는지 확인한다. 정식 컨트랙트 바인딩(코드 생성) 없이, web3j로 함수 하나(TicketVault의
 * hasRole/grantRole/balanceOf/deposit)를 직접 인코딩해서 호출한다 - 되는 것만 확인하고 나면
 * 이 패턴 위에 정식 서비스를 얹는다.
 *
 * <p>{@code ADMIN_PRIVATE_KEY} 환경변수가 없으면(로컬 실행자가 blockchain/.env 값을 안 넣었으면)
 * 테스트를 스킵한다 - CI 등 이 키가 없는 환경에서 실패하지 않기 위해서다.
 */
class TicketVaultRpcSpikeTest {

    private static final String RPC_URL = "http://network.ticketmoa.site:8545";
    private static final String TICKET_VAULT_ADDRESS = "0xdD118811921b1B04E23aBFEe9f86572dD2C92774";

    @Test
    @DisplayName("실제 체인에 deposit 트랜잭션을 보내면 balanceOf가 그만큼 늘어난다")
    void deposit_increasesOnChainBalance() throws Exception {
        String adminPrivateKey = System.getenv("ADMIN_PRIVATE_KEY");
        assumeTrue(adminPrivateKey != null && !adminPrivateKey.isBlank(),
                "ADMIN_PRIVATE_KEY 환경변수가 없어 스킵합니다 (blockchain/.env 값을 export 하세요)");

        Web3j web3j = Web3j.build(new HttpService(RPC_URL));
        Credentials credentials = Credentials.create(adminPrivateKey);
        long chainId = web3j.ethChainId().send().getChainId().longValue();
        RawTransactionManager txManager = new RawTransactionManager(web3j, credentials, chainId);
        String adminAddress = credentials.getAddress();

        ensureOperatorRole(web3j, txManager, adminAddress);

        BigInteger balanceBefore = balanceOf(web3j, adminAddress);

        BigInteger amount = BigInteger.valueOf(1000);
        byte[] refId = Hash.sha3(("spike-" + System.nanoTime()).getBytes(StandardCharsets.UTF_8));
        TransactionReceipt receipt = sendTransaction(web3j, txManager, new Function(
                "deposit",
                List.of(new Address(adminAddress), new Uint256(amount), new Bytes32(refId)),
                Collections.emptyList()));
        assertThat(receipt.isStatusOK()).as("deposit 트랜잭션이 온체인에서 실패함").isTrue();

        BigInteger balanceAfter = balanceOf(web3j, adminAddress);
        assertThat(balanceAfter).isEqualTo(balanceBefore.add(amount));
    }

    /** OPERATOR_ROLE이 없으면(첫 실행 등) DEFAULT_ADMIN_ROLE 권한으로 스스로에게 부여한다. */
    private void ensureOperatorRole(Web3j web3j, RawTransactionManager txManager, String adminAddress) throws Exception {
        byte[] operatorRole = Hash.sha3("OPERATOR_ROLE".getBytes(StandardCharsets.UTF_8));

        boolean hasOperatorRole = (Boolean) call(web3j, new Function(
                "hasRole",
                List.of(new Bytes32(operatorRole), new Address(adminAddress)),
                List.of(new TypeReference<Bool>() {}))).get(0).getValue();

        if (!hasOperatorRole) {
            sendTransaction(web3j, txManager, new Function(
                    "grantRole",
                    List.of(new Bytes32(operatorRole), new Address(adminAddress)),
                    Collections.emptyList()));
        }
    }

    private BigInteger balanceOf(Web3j web3j, String address) throws Exception {
        return (BigInteger) call(web3j, new Function(
                "balanceOf",
                List.of(new Address(address)),
                List.of(new TypeReference<Uint256>() {}))).get(0).getValue();
    }

    private List<Type> call(Web3j web3j, Function function) throws Exception {
        String encodedFunction = FunctionEncoder.encode(function);
        EthCall response = web3j.ethCall(
                Transaction.createEthCallTransaction(null, TICKET_VAULT_ADDRESS, encodedFunction),
                DefaultBlockParameterName.LATEST
        ).send();
        if (response.hasError()) {
            throw new IllegalStateException("eth_call 실패: " + response.getError().getMessage());
        }
        return FunctionReturnDecoder.decode(response.getValue(), function.getOutputParameters());
    }

    private TransactionReceipt sendTransaction(Web3j web3j, RawTransactionManager txManager, Function function) throws Exception {
        String encodedFunction = FunctionEncoder.encode(function);
        EthSendTransaction sendResponse = txManager.sendTransaction(
                DefaultGasProvider.GAS_PRICE, DefaultGasProvider.GAS_LIMIT,
                TICKET_VAULT_ADDRESS, encodedFunction, BigInteger.ZERO, false);
        if (sendResponse.hasError()) {
            throw new IllegalStateException("트랜잭션 전송 실패: " + sendResponse.getError().getMessage());
        }

        PollingTransactionReceiptProcessor receiptProcessor = new PollingTransactionReceiptProcessor(web3j, 1000, 30);
        return receiptProcessor.waitForTransactionReceipt(sendResponse.getTransactionHash());
    }
}
