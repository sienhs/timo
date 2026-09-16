package com.ssafy.timo.domain.blockchain;

import java.math.BigInteger;
import java.util.List;
import org.web3j.abi.FunctionEncoder;
import org.web3j.abi.FunctionReturnDecoder;
import org.web3j.abi.datatypes.Function;
import org.web3j.abi.datatypes.Type;
import org.web3j.crypto.Hash;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.DefaultBlockParameterName;
import org.web3j.protocol.core.methods.request.Transaction;
import org.web3j.protocol.core.methods.response.EthCall;
import org.web3j.protocol.core.methods.response.EthSendTransaction;
import org.web3j.protocol.core.methods.response.Log;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.tx.RawTransactionManager;
import org.web3j.tx.gas.DefaultGasProvider;
import org.web3j.tx.response.PollingTransactionReceiptProcessor;
import org.web3j.utils.Numeric;

/**
 * {@code TicketVaultRpcSpikeTest}에서 검증한 "코드 생성 바인딩 없이 web3j로 함수를 직접
 * 인코딩해 호출하는" 패턴을 재사용 가능한 형태로 옮긴 것. 컨트랙트별 클라이언트({@code TicketVaultClient} 등)가
 * 이 위에 얹혀 함수 이름과 파라미터만 채운다.
 *
 * <p>모든 쓰기 호출은 트랜잭션이 블록에 포함될 때까지 동기적으로 기다린다({@link #sendAndWait}) -
 * 정오는 논리적으로 감춰지고, 실패는 예외로만 드러난다. 호출부(비동기 정산 워커)가 재시도·보상
 * 로직을 결정한다.
 */
public class ContractClient {

    private static final int RECEIPT_POLL_INTERVAL_MS = 1000;
    private static final int RECEIPT_MAX_ATTEMPTS = 30;

    private final Web3j web3j;
    private final RawTransactionManager transactionManager;
    private final String contractAddress;

    public ContractClient(Web3j web3j, RawTransactionManager transactionManager, String contractAddress) {
        this.web3j = web3j;
        this.transactionManager = transactionManager;
        this.contractAddress = contractAddress;
    }

    /** keccak256 해시. 역할 상수(예: {@code OPERATOR_ROLE})와 idempotency ref/orderId 생성에 쓴다. */
    public static byte[] keccak256(String input) {
        return Hash.sha3(input.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    @SuppressWarnings("unchecked")
    protected <T> T call(Function function) {
        try {
            String encoded = FunctionEncoder.encode(function);
            EthCall response = web3j.ethCall(
                    Transaction.createEthCallTransaction(null, contractAddress, encoded),
                    DefaultBlockParameterName.LATEST
            ).send();
            if (response.hasError()) {
                throw new ContractCallException("eth_call 실패: " + response.getError().getMessage());
            }
            List<Type> decoded = FunctionReturnDecoder.decode(response.getValue(), function.getOutputParameters());
            return (T) decoded.get(0).getValue();
        } catch (ContractCallException e) {
            throw e;
        } catch (Exception e) {
            throw new ContractCallException("eth_call 중 오류: " + function.getName(), e);
        }
    }

    /**
     * 상태 변경 함수의 리턴값은 트랜잭션 영수증에 직접 담기지 않는다 - 대신 그 함수가 emit한
     * 이벤트의 indexed 파라미터를 로그에서 읽는다({@code ShowRegistry.registerShow}의 showId 등).
     *
     * @param eventSignature 정규화된 이벤트 시그니처, 예: {@code "ShowRegistered(uint256,address,uint256,uint256,uint256,uint256)"}
     * @param topicIndex     읽을 topic 위치 (0은 이벤트 해시 자신이므로, 첫 번째 indexed 파라미터는 1)
     */
    protected BigInteger extractIndexedUint256(TransactionReceipt receipt, String eventSignature, int topicIndex) {
        String eventHash = Numeric.toHexString(keccak256(eventSignature));
        for (Log log : receipt.getLogs()) {
            if (log.getTopics().get(0).equalsIgnoreCase(eventHash)) {
                return Numeric.toBigInt(log.getTopics().get(topicIndex));
            }
        }
        throw new ContractCallException("이벤트를 로그에서 찾지 못함: " + eventSignature);
    }

    protected TransactionReceipt sendAndWait(Function function) {
        try {
            String encoded = FunctionEncoder.encode(function);
            EthSendTransaction sent = transactionManager.sendTransaction(
                    DefaultGasProvider.GAS_PRICE, DefaultGasProvider.GAS_LIMIT,
                    contractAddress, encoded, BigInteger.ZERO, false);
            if (sent.hasError()) {
                throw new ContractCallException("트랜잭션 전송 실패(" + function.getName() + "): " + sent.getError().getMessage());
            }

            PollingTransactionReceiptProcessor receiptProcessor =
                    new PollingTransactionReceiptProcessor(web3j, RECEIPT_POLL_INTERVAL_MS, RECEIPT_MAX_ATTEMPTS);
            TransactionReceipt receipt = receiptProcessor.waitForTransactionReceipt(sent.getTransactionHash());
            if (!receipt.isStatusOK()) {
                throw new ContractCallException("트랜잭션이 온체인에서 revert됨(" + function.getName() + "): " + receipt.getTransactionHash());
            }
            return receipt;
        } catch (ContractCallException e) {
            throw e;
        } catch (Exception e) {
            throw new ContractCallException("트랜잭션 처리 중 오류: " + function.getName(), e);
        }
    }
}
