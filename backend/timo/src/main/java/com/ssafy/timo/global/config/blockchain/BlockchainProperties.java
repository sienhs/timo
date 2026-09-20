package com.ssafy.timo.global.config.blockchain;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 온체인 연동 설정. 배포된 컨트랙트 주소는 여기 없다 - {@link DeployedContractAddresses} 참고.
 *
 * <p>{@code adminPrivateKey}는 yml에 직접 쓰지 않고 환경변수(blockchain/.env의
 * {@code ADMIN_PRIVATE_KEY})로만 주입한다. 값이 비어 있으면 {@link #hasRealAdminPrivateKey()}가
 * false를 반환해 체인 호출이 필요한 코드가 스스로 건너뛸 수 있게 한다 - 로컬/테스트용 더미 서명
 * 계정은 {@link Web3jConfig#adminCredentials}가 그때그때 생성한다.
 *
 * @param rpcUrl          체인 RPC 엔드포인트
 * @param adminPrivateKey 백엔드가 대신 서명할 때 쓰는 admin 지갑 개인키 (0x 접두 64자리 hex)
 */
@ConfigurationProperties(prefix = "blockchain")
public record BlockchainProperties(String rpcUrl, String adminPrivateKey) {

    public boolean hasRealAdminPrivateKey() {
        return adminPrivateKey != null && !adminPrivateKey.isBlank();
    }
}
