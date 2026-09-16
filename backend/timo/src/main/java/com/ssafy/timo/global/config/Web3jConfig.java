package com.ssafy.timo.global.config;

import java.util.regex.Pattern;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.web3j.crypto.Credentials;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.http.HttpService;
import org.web3j.tx.RawTransactionManager;

/**
 * 온체인 연동에 쓰는 web3j 빈들. {@link BlockchainProperties#adminPrivateKey()}가 서명 주체이고,
 * {@code ORGANIZER_ROLE}·{@code OPERATOR_ROLE}·{@code MARKETPLACE_ROLE}을 전부 겸한다 - 실제 사용자
 * 지갑 키로 서명해야 하는 것은 {@code ownerOf(tokenId) == msg.sender}를 요구하는 함수(양도 등록·취소)
 * 뿐이고, 나머지는 전부 역할 기반이라 admin 지갑 하나로 충분하다.
 *
 * <p>chainId는 기동 시점에 네트워크를 조회하지 않고 설정값으로 고정한다 - 체인이 하나로 고정된
 * 지금 구조에서 기동 때마다 원격 호출을 추가할 이유가 없다.
 */
@Configuration
@EnableConfigurationProperties(BlockchainProperties.class)
public class Web3jConfig {

    private static final Pattern PRIVATE_KEY_FORMAT = Pattern.compile("^0x[0-9a-fA-F]{64}$");
    private static final long CHAIN_ID = 31337L; // SSAFY EC2에 올린 persistent Hardhat 노드

    @Bean
    public Web3j web3j(BlockchainProperties properties) {
        return Web3j.build(new HttpService(properties.rpcUrl()));
    }

    @Bean
    public Credentials adminCredentials(BlockchainProperties properties) {
        String privateKey = properties.adminPrivateKey();
        if (privateKey == null || privateKey.isBlank()) {
            throw new IllegalStateException(
                    "blockchain.admin-private-key 가 설정되지 않았습니다. blockchain/.env 의 ADMIN_PRIVATE_KEY 값을 "
                            + "ADMIN_PRIVATE_KEY 환경변수로 내보내세요.");
        }
        if (!PRIVATE_KEY_FORMAT.matcher(privateKey).matches()) {
            throw new IllegalStateException("blockchain.admin-private-key 는 0x 접두 64자리 16진수여야 합니다.");
        }
        return Credentials.create(privateKey);
    }

    @Bean
    public RawTransactionManager adminTransactionManager(Web3j web3j, Credentials adminCredentials) {
        return new RawTransactionManager(web3j, adminCredentials, CHAIN_ID);
    }
}
