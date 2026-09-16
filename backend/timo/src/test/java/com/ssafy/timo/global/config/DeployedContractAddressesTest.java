package com.ssafy.timo.global.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.web3j.crypto.Credentials;

/**
 * {@link DeployedContractAddresses}가 admin 지갑으로부터 컨트랙트 주소를 올바르게 계산하는지 확인한다.
 *
 * <p>Hardhat의 공개적으로 알려진 0번 계정 키를 쓴다 - 실제 체인 접속 없이도, "이 주소가 nonce
 * 0/1/2로 배포했다면 컨트랙트가 어디에 생기는가"라는 순수 계산이라 검증할 수 있다. 기대값은
 * {@code ethers.getCreateAddress({ from, nonce })}로 독립적으로 계산해 대조한 값이다 -
 * blockchain/scripts/deploy/deploy.ts를 이 키로 로컬 실행하면 실제로 이 주소들에 배포된다
 * (Hardhat 새 노드에서 0번 계정이 처음 배포하는 컨트랙트 주소로 커뮤니티에 잘 알려진 값이기도
 * 하다).
 */
class DeployedContractAddressesTest {

    // Hardhat 문서/샘플 프로젝트에 공개된 20개 기본 계정 중 0번 - 실제 자금이 얹힌 적 없는 테스트 전용 키.
    private static final String HARDHAT_ACCOUNT_0_PRIVATE_KEY =
            "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

    private final DeployedContractAddresses addresses =
            new DeployedContractAddresses(Credentials.create(HARDHAT_ACCOUNT_0_PRIVATE_KEY));

    @Test
    void computesShowRegistryAsTheFirstContractDeployedByThisAccount() {
        assertThat(addresses.showRegistryAddress()).isEqualToIgnoringCase("0x5FbDB2315678afecb367f032d93F642f64180aa3");
    }

    @Test
    void computesTicketNftAsTheSecondContractDeployedByThisAccount() {
        assertThat(addresses.ticketNftAddress()).isEqualToIgnoringCase("0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512");
    }

    @Test
    void computesTicketVaultAsTheThirdContractDeployedByThisAccount() {
        assertThat(addresses.ticketVaultAddress()).isEqualToIgnoringCase("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0");
    }

    @Test
    void differentAdminKeysComputeDifferentAddresses() {
        DeployedContractAddresses other = new DeployedContractAddresses(
                Credentials.create("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"));

        assertThat(other.ticketVaultAddress()).isNotEqualToIgnoringCase(addresses.ticketVaultAddress());
    }
}
