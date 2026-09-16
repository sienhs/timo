package com.ssafy.timo.global.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 온체인 연동 설정. RPC 노드 주소, 백엔드 admin 지갑의 개인키(ORGANIZER_ROLE·OPERATOR_ROLE 보유),
 * 컨트랙트 주소들을 담는다.
 *
 * <p>{@code adminPrivateKey}는 절대 yml에 직접 쓰지 않는다 - 환경변수(blockchain/.env의
 * {@code ADMIN_PRIVATE_KEY})로만 주입한다. 로컬에서 이 값 없이 뜨면 {@link Web3jConfig}가 서명이
 * 필요한 기능을 못 쓰는 상태로만 남기고, 앱 자체는 계속 뜬다 - 체인 연동 없이 다른 작업을 할 수 있어야
 * 하기 때문이다.
 *
 * @param rpcUrl               체인 RPC 엔드포인트
 * @param adminPrivateKey      백엔드가 대신 서명할 때 쓰는 admin 지갑 개인키 (0x 접두 64자리 hex)
 * @param ticketVaultAddress   TicketVault 컨트랙트 주소
 * @param ticketNftAddress     TicketNFT 컨트랙트 주소
 * @param showRegistryAddress  ShowRegistry 컨트랙트 주소
 */
@ConfigurationProperties(prefix = "blockchain")
public record BlockchainProperties(
        String rpcUrl,
        String adminPrivateKey,
        String ticketVaultAddress,
        String ticketNftAddress,
        String showRegistryAddress) {

    /**
     * {@code local}·{@code test}·{@code securitytest} 프로필이 {@code ADMIN_PRIVATE_KEY}를
     * 내보내지 않았을 때 쓰는, 형식만 유효한 더미 키(application*.yml 참고). 실제 체인 접근 전에
     * 이 값인지 먼저 확인하면, 어차피 실패할 네트워크 호출을 시도하다 타임아웃으로 느려지는 대신
     * 곧바로 건너뛸 수 있다.
     */
    public static final String LOCAL_DUMMY_ADMIN_PRIVATE_KEY =
            "0x1111111111111111111111111111111111111111111111111111111111111111";

    public boolean hasRealAdminPrivateKey() {
        return adminPrivateKey != null && !adminPrivateKey.equals(LOCAL_DUMMY_ADMIN_PRIVATE_KEY);
    }
}
