package com.ssafy.timo.global.config;

import java.math.BigInteger;

import org.springframework.stereotype.Component;
import org.web3j.crypto.ContractUtils;
import org.web3j.crypto.Credentials;

/**
 * {@code blockchain/scripts/deploy/deploy.ts}는 {@link Web3jConfig#adminCredentials}와 같은 admin
 * 지갑으로, 항상 같은 순서(ShowRegistry → TicketNFT → TicketVault → Marketplace)로 4개 컨트랙트를
 * 배포한다. 이더리움 CREATE 규칙상 배포 주소는 {@code keccak256(rlp(sender, nonce))}의 마지막
 * 20바이트뿐이라 - 다른 어떤 것도 안 섞인다 - 같은 계정이 같은 순서로 다시 배포하면 매번 정확히 같은
 * 주소가 나온다. EC2 컨테이너가 재시작마다 이 스크립트를 다시 돌려도(README의 "EC2 상시 구동" 참고)
 * 여기서 계산한 주소가 그대로 맞기 때문에, 주소를 yml에 박아두고 재배포 때마다 손으로 맞춰줄 필요가
 * 없다.
 *
 * <p>이 전제가 깨지는 경우는 단 하나: 이 admin 계정이 그 배포 스크립트를 실행하기 *전에* 다른
 * 트랜잭션을 보내 nonce가 앞당겨지는 경우뿐이다 - 이 계정은 오직 배포 전용으로만 써야 한다.
 *
 * <p>주소는 빈이 만들어질 때 한 번만 계산해서 들고 있는다 - 매 호출마다 공개키를 다시 유도할 이유가
 * 없고, {@link Web3jConfig#adminCredentials}가 이미 개인키 형식을 검증해 뒀으니 여기서 다시
 * {@code Credentials.create}를 부르며 검증을 중복하지 않는다.
 */
@Component
public class DeployedContractAddresses {

    private final String showRegistryAddress;
    private final String ticketNftAddress;
    private final String ticketVaultAddress;

    public DeployedContractAddresses(Credentials adminCredentials) {
        String adminAddress = adminCredentials.getAddress();
        this.showRegistryAddress = ContractUtils.generateContractAddress(adminAddress, BigInteger.valueOf(0));
        this.ticketNftAddress = ContractUtils.generateContractAddress(adminAddress, BigInteger.valueOf(1));
        this.ticketVaultAddress = ContractUtils.generateContractAddress(adminAddress, BigInteger.valueOf(2));
    }

    public String showRegistryAddress() {
        return showRegistryAddress;
    }

    public String ticketNftAddress() {
        return ticketNftAddress;
    }

    public String ticketVaultAddress() {
        return ticketVaultAddress;
    }
}
