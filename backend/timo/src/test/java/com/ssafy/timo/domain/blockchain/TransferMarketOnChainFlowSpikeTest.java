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
import org.web3j.crypto.Hash;
import org.web3j.crypto.Keys;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.http.HttpService;
import org.web3j.tx.RawTransactionManager;

/**
 * [스파이크] {@link TicketNftClient#listForTransferFor}로 연 매물을 {@link MarketplaceClient#buy}가
 * 실제 체인 위에서 NFT 소유권과 {@link TicketVaultClient} 잔액을 한 트랜잭션으로 정확히 옮기는지
 * 확인한다 - {@link BookingOnChainFlowSpikeTest}의 예매 파이프라인에 이어, 양도 체결
 * ({@code TicketTransferServiceImpl}이 쓰는 경로) 쪽을 검증한다.
 *
 * <p>{@code ADMIN_PRIVATE_KEY}가 없으면 스킵한다.
 */
class TransferMarketOnChainFlowSpikeTest {

    private static final String RPC_URL = "http://network.ticketmoa.site:8545";

    @Test
    void listThenBuy_movesNftAndFunds() throws Exception {
        String adminPrivateKey = System.getenv("ADMIN_PRIVATE_KEY");
        assumeTrue(adminPrivateKey != null && !adminPrivateKey.isBlank(),
                "ADMIN_PRIVATE_KEY 환경변수가 없어 스킵합니다 (blockchain/.env 값을 export 하세요)");

        Web3j web3j = Web3j.build(new HttpService(RPC_URL));
        Credentials admin = Credentials.create(adminPrivateKey);
        RawTransactionManager txManager = new RawTransactionManager(web3j, admin, 31337L);
        String adminAddress = admin.getAddress();

        DeployedContractAddresses addresses = new DeployedContractAddresses(admin);

        ensureRole(web3j, txManager, addresses.showRegistryAddress(), "ORGANIZER_ROLE", adminAddress);
        ensureRole(web3j, txManager, addresses.ticketNftAddress(), "ORGANIZER_ROLE", adminAddress);
        ensureRole(web3j, txManager, addresses.ticketNftAddress(), "OPERATOR_ROLE", adminAddress);
        ensureRole(web3j, txManager, addresses.ticketVaultAddress(), "OPERATOR_ROLE", adminAddress);
        ensureRole(web3j, txManager, addresses.marketplaceAddress(), "OPERATOR_ROLE", adminAddress);
        // Marketplace.buy()가 내부에서 부르는 settleTransfer는 admin이 아니라 Marketplace 컨트랙트
        // 자신이 호출자다 - deploy.ts가 배포 시 한 번 부여하지만, 이 체인이 그 스크립트를 안 거쳤을
        // 수도 있으니 여기서도 멱등하게 보장해 둔다.
        ensureRole(web3j, txManager, addresses.ticketNftAddress(), "MARKETPLACE_ROLE", addresses.marketplaceAddress());
        ensureRole(web3j, txManager, addresses.ticketVaultAddress(), "MARKETPLACE_ROLE", addresses.marketplaceAddress());

        ShowRegistryClient showRegistry = new ShowRegistryClient(web3j, txManager, addresses);
        TicketNftClient ticketNft = new TicketNftClient(web3j, txManager, addresses);
        TicketVaultClient ticketVault = new TicketVaultClient(web3j, txManager, addresses);
        MarketplaceClient marketplace = new MarketplaceClient(web3j, txManager, addresses);

        BigInteger facePrice = BigInteger.valueOf(50_000);
        List<BigInteger> sectionPrices = List.of(facePrice, facePrice, facePrice, facePrice, facePrice);
        long saleOpenTime = Instant.now().minus(1, ChronoUnit.HOURS).getEpochSecond();
        long showTime = Instant.now().plus(1, ChronoUnit.DAYS).getEpochSecond();
        BigInteger showId = showRegistry.registerShow(
                sectionPrices, BigInteger.valueOf(100), saleOpenTime, showTime, "ipfs://spike-transfer-test");

        // 서명이 필요 없는 두 지갑 - 이 흐름에서 alice/bob은 서명하지 않고 admin이 대신 처리한다.
        String aliceAddress = Credentials.create(Keys.createEcKeyPair()).getAddress();
        String bobAddress = Credentials.create(Keys.createEcKeyPair()).getAddress();

        BigInteger seatId = BigInteger.valueOf(System.nanoTime() % 1_000_000); // 이 show에서 처음 쓰는 seatId만 보장하면 됨
        MintResult minted = ticketNft.mintTicket(aliceAddress, showId, seatId, 0);
        BigInteger tokenId = minted.tokenId();
        assertThat(ticketNft.ownerOf(tokenId)).isEqualToIgnoringCase(aliceAddress);

        BigInteger askPrice = BigInteger.valueOf(40_000);
        ticketNft.listForTransferFor(tokenId, aliceAddress, askPrice);

        ticketVault.deposit(bobAddress, askPrice, ContractClient.keccak256("spike-deposit-" + System.nanoTime()));
        assertThat(ticketVault.balanceOf(bobAddress)).isEqualTo(askPrice);

        byte[] tradeId = ContractClient.keccak256("spike-trade-" + System.nanoTime());
        String txHash = marketplace.buy(tokenId, bobAddress, tradeId);
        assertThat(txHash).isNotBlank();

        assertThat(ticketNft.ownerOf(tokenId)).isEqualToIgnoringCase(bobAddress);
        assertThat(ticketVault.balanceOf(bobAddress)).isEqualTo(BigInteger.ZERO);
        assertThat(ticketVault.balanceOf(aliceAddress)).isEqualTo(askPrice);
    }

    /** DEFAULT_ADMIN_ROLE 권한으로, 없으면 스스로에게(또는 지정한 address에) 역할을 부여한다(최초 실행 대비). */
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
