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
}
