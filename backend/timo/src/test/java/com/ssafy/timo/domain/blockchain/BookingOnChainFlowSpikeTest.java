package com.ssafy.timo.domain.blockchain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import com.ssafy.timo.global.config.blockchain.DeployedContractAddresses;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.web3j.abi.TypeReference;
import org.web3j.abi.datatypes.Address;
import org.web3j.abi.datatypes.Bool;
import org.web3j.abi.datatypes.Function;
import org.web3j.abi.datatypes.generated.Bytes32;
import org.web3j.crypto.Credentials;
import org.web3j.crypto.ECKeyPair;
import org.web3j.crypto.Hash;
import org.web3j.crypto.Keys;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.http.HttpService;
import org.web3j.tx.RawTransactionManager;

/**
 * [스파이크] {@link TicketVaultClient}/{@link TicketNftClient}/{@link ShowRegistryClient} 가
 * 실제 EC2 체인 위에서 "공연 등록 -> 충전 -> 예매 확정 차감 -> 민팅" 전체 파이프라인을 정확히
 * 수행하는지 확인한다. 특히 반환값이 영수증에 없어 이벤트 로그/매핑을 다시 읽어야 하는
 * {@code registerShow}/{@code mintTicket} 의 처리가 실제 체인에서도 맞는지가 핵심이다.
 *
 * <p>{@code ADMIN_PRIVATE_KEY} 가 없으면 스킵한다.
 */
class BookingOnChainFlowSpikeTest {

    private static final String RPC_URL = "http://network.ticketmoa.site:8545";

    @Test
    void bookingPipeline_registersShowChargesAndMints() throws Exception {
        String adminPrivateKey = System.getenv("ADMIN_PRIVATE_KEY");
        assumeTrue(adminPrivateKey != null && !adminPrivateKey.isBlank(),
                "ADMIN_PRIVATE_KEY 환경변수가 없어 스킵합니다 (blockchain/.env 값을 export 하세요)");

        Web3j web3j = Web3j.build(new HttpService(RPC_URL));
        Credentials admin = Credentials.create(adminPrivateKey);
        RawTransactionManager txManager = new RawTransactionManager(web3j, admin, 31337L);
        String adminAddress = admin.getAddress();

        // DeployedContractAddresses가 컨트랙트 주소를 이 admin 키로부터 계산하므로(하드코딩 없음),
        // 이 스파이크 테스트가 통과한다는 것 자체가 그 계산이 실제 체인 위 배포와 맞다는 증거다.
        DeployedContractAddresses addresses = new DeployedContractAddresses(admin);

        ensureRole(web3j, txManager, addresses.ticketVaultAddress(), "OPERATOR_ROLE", adminAddress);
        ensureRole(web3j, txManager, addresses.showRegistryAddress(), "ORGANIZER_ROLE", adminAddress);
        ensureRole(web3j, txManager, addresses.ticketNftAddress(), "ORGANIZER_ROLE", adminAddress);

        ShowRegistryClient showRegistry = new ShowRegistryClient(web3j, txManager, addresses);
        TicketVaultClient ticketVault = new TicketVaultClient(web3j, txManager, addresses);
        TicketNftClient ticketNft = new TicketNftClient(web3j, txManager, addresses);

        // 조직자는 admin 지갑이 대신 등록하지만, 온체인 organizer 기록 자체는 admin 주소로 남는다.
        BigInteger facePrice = BigInteger.valueOf(50_000);
        int sectionIndex = 0;
        List<BigInteger> sectionPrices = List.of(facePrice, facePrice, facePrice, facePrice, facePrice);
        long saleOpenTime = Instant.now().minus(1, ChronoUnit.HOURS).getEpochSecond();
        long showTime = Instant.now().plus(1, ChronoUnit.DAYS).getEpochSecond();
        BigInteger showId =
                showRegistry.registerShow(sectionPrices, BigInteger.valueOf(100), saleOpenTime, showTime, "ipfs://spike-test");
        assertThat(showId).isGreaterThan(BigInteger.ZERO);
        assertThat(showRegistry.isSaleOpen(showId)).isTrue();

        // 실제 서명이 필요 없는 매수자 - 이 흐름에서 매수자는 서명하지 않고 admin이 대신 처리한다.
        ECKeyPair buyerKeyPair = Keys.createEcKeyPair();
        String buyerAddress = Credentials.create(buyerKeyPair).getAddress();

        byte[] depositRef = ContractClient.keccak256("spike-deposit-" + System.nanoTime());
        ticketVault.deposit(buyerAddress, facePrice, depositRef);
        assertThat(ticketVault.balanceOf(buyerAddress)).isEqualTo(facePrice);

        byte[] orderId = ContractClient.keccak256("spike-order-" + System.nanoTime());
        BigInteger seatId = BigInteger.valueOf(System.nanoTime() % 1_000_000); // 이 show에서 처음 쓰는 seatId만 보장하면 됨
        ticketVault.chargeForBooking(buyerAddress, adminAddress, facePrice, orderId);
        assertThat(ticketVault.balanceOf(buyerAddress)).isEqualTo(BigInteger.ZERO);

        MintResult mintResult = ticketNft.mintTicket(buyerAddress, showId, seatId, sectionIndex);
        assertThat(mintResult.tokenId()).isGreaterThan(BigInteger.ZERO);
        assertThat(mintResult.transactionHash()).isNotBlank();
        assertThat(ticketNft.ownerOf(mintResult.tokenId())).isEqualToIgnoringCase(buyerAddress);
    }

    /** DEFAULT_ADMIN_ROLE 권한으로, 없으면 스스로에게 역할을 부여한다(최초 실행 대비). */
    private void ensureRole(Web3j web3j, RawTransactionManager txManager, String contractAddress, String roleName, String address) throws Exception {
        byte[] role = Hash.sha3(roleName.getBytes(StandardCharsets.UTF_8));

        boolean hasRole = (Boolean) callRaw(web3j, contractAddress, new Function(
                "hasRole",
                List.of(new Bytes32(role), new Address(address)),
                List.of(new TypeReference<Bool>() {}))).get(0).getValue();

        if (!hasRole) {
            String encoded = org.web3j.abi.FunctionEncoder.encode(new Function(
                    "grantRole", List.of(new Bytes32(role), new Address(address)), Collections.emptyList()));
            var sent = txManager.sendTransaction(
                    org.web3j.tx.gas.DefaultGasProvider.GAS_PRICE, org.web3j.tx.gas.DefaultGasProvider.GAS_LIMIT,
                    contractAddress, encoded, BigInteger.ZERO, false);
            new org.web3j.tx.response.PollingTransactionReceiptProcessor(web3j, 1000, 30)
                    .waitForTransactionReceipt(sent.getTransactionHash());
        }
    }

    private List<org.web3j.abi.datatypes.Type> callRaw(Web3j web3j, String contractAddress, Function function) throws Exception {
        String encoded = org.web3j.abi.FunctionEncoder.encode(function);
        var response = web3j.ethCall(
                org.web3j.protocol.core.methods.request.Transaction.createEthCallTransaction(null, contractAddress, encoded),
                org.web3j.protocol.core.DefaultBlockParameterName.LATEST
        ).send();
        return org.web3j.abi.FunctionReturnDecoder.decode(response.getValue(), function.getOutputParameters());
    }
}
