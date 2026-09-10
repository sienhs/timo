package com.ssafy.timo.domain.wallet.crypto;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.exc.UnrecognizedPropertyException;

import java.math.BigInteger;

import java.nio.charset.StandardCharsets;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import org.web3j.crypto.Credentials;
import org.web3j.crypto.ECKeyPair;
import org.web3j.crypto.Keys;
import org.web3j.crypto.Sign;
import org.web3j.crypto.Wallet;
import org.web3j.crypto.WalletFile;
import org.web3j.crypto.exception.CipherException;

/**
 * web3j 키스토어 암복호화 및 ethers.js 키스토어 호환성 검증.
 *
 * <p>S15P21D206-225에서 스파이크로 시작했으나, {@link CustodialWalletCrypto}가 앞으로도 이 호환성에 의존하므로 회귀 테스트로 남긴다.
 * <p>web3j 버전을 올렸을 때 이 동작이 깨지면 여기서 바로 잡힌다.
 */
class Web3jKeystoreCompatibilityTest {

    private static final String PASSWORD = "spike-test-password";

    @Nested
    @DisplayName("web3j 키스토어 암복호화 및 서명")
    class Web3jOnlyRoundTrip {

        @Test
        @DisplayName("키스토어 JSON 직렬화·역직렬화 후 복호화한 개인키가 원본과 일치한다")
        void encryptDecryptRoundTrip_keepsTheSameKey() throws Exception {
            ECKeyPair original = Keys.createEcKeyPair();

            // 테스트 실행 시간을 줄이기 위해 LIGHT 설정 사용
            WalletFile encrypted = Wallet.createLight(PASSWORD, original);

            // 저장·조회 시 JSON 직렬화로 인한 키 손실 여부 확인
            ObjectMapper objectMapper = new ObjectMapper();
            String savedJson = objectMapper.writeValueAsString(encrypted);
            WalletFile loaded = objectMapper.readValue(savedJson, WalletFile.class);

            ECKeyPair decrypted = Wallet.decrypt(PASSWORD, loaded);

            assertThat(decrypted.getPrivateKey()).isEqualTo(original.getPrivateKey());
        }

        @Test
        @DisplayName("복호화한 키의 서명에서 원본 주소를 복구한다")
        void decryptedKey_canActuallySign() throws Exception {
            ECKeyPair original = Keys.createEcKeyPair();
            String address = Keys.getAddress(original);

            WalletFile encrypted = Wallet.createLight(PASSWORD, original);
            ECKeyPair decrypted = Wallet.decrypt(PASSWORD, encrypted);

            assertSignatureRecoversToAddress(decrypted, address);
        }

        @Test
        @DisplayName("잘못된 비밀번호로 복호화하면 CipherException이 발생한다")
        void wrongPassword_failsLoudlyInsteadOfReturningGarbageKey() throws Exception {
            WalletFile encrypted = Wallet.createLight(PASSWORD, Keys.createEcKeyPair());

            assertThatThrownBy(() -> Wallet.decrypt("wrong-password", encrypted))
                    .isInstanceOf(CipherException.class);
        }
    }

    @Nested
    @DisplayName("ethers.js 키스토어 호환성")
    class EthersKeystoreCompatibility {

        // custodialWallet.ts와 동일한 방식으로 생성한 ethers.js 키스토어 픽스처.
        // Crypto 필드와 x-ethers 메타데이터를 포함한다.
        private static final String ETHERS_ADDRESS = "0xF90259A926dE751ed07d2e8908868A3d2D2C4a7A";
        private static final String ETHERS_DEK_HEX =
                "5b900621bd1801486535c4c4a45ba00d537498b163b5bbf05ca0b08f98e6b2ea";
        private static final String ETHERS_KEYSTORE_JSON = """
                {
                  "address": "f90259a926de751ed07d2e8908868a3d2d2c4a7a",
                  "id": "51cf5898-7b4d-4dff-accc-7f4c80d0e151",
                  "version": 3,
                  "Crypto": {
                    "cipher": "aes-128-ctr",
                    "cipherparams": { "iv": "8c33ccfe487ddaf78c4c6a4545a138fa" },
                    "ciphertext": "ab2d8e5e62c16fe74a6ee262fd38322e916ac82006f859baae1b3b0411335af6",
                    "kdf": "scrypt",
                    "kdfparams": {
                      "salt": "ee00f4ce9c1ebe6c075e3c5bb4c07966bbad4a264b57ee4fe811b85d291c292c",
                      "n": 131072,
                      "dklen": 32,
                      "p": 1,
                      "r": 8
                    },
                    "mac": "8cfab48f4fff584813a831e2fd6d13ec90371919e1da41fcf10e10f75fa3a2a6"
                  },
                  "x-ethers": {
                    "client": "ethers/6.17.0",
                    "gethFilename": "UTC--2026-09-10T01-29-37.0Z--f90259a926de751ed07d2e8908868a3d2d2c4a7a",
                    "path": "m/44'/60'/0'/0/0",
                    "locale": "en",
                    "mnemonicCounter": "5f414cebe71fcdc29945c61bcaa3b64a",
                    "mnemonicCiphertext": "aa2839a376f27f4c4230642d8e30c342",
                    "version": "0.1"
                  }
                }
                """;

        @Test
        @DisplayName("기본 ObjectMapper는 x-ethers 필드 역직렬화 시 예외가 발생한다")
        void defaultObjectMapper_rejectsTheUnknownEthersField() {
            ObjectMapper strictMapper = new ObjectMapper();

            // Crypto는 지원되지만 x-ethers는 기본 역직렬화 설정에서 예외 발생
            assertThatThrownBy(() -> strictMapper.readValue(ETHERS_KEYSTORE_JSON, WalletFile.class))
                    .isInstanceOf(UnrecognizedPropertyException.class)
                    .hasMessageContaining("x-ethers");
        }

        @Test
        @DisplayName("알 수 없는 필드를 무시하면 ethers.js 키스토어 복호화 및 서명에 성공한다")
        void lenientObjectMapper_decryptsAndSignsWithTheRealEthersKeystore() throws Exception {
            ObjectMapper lenientMapper = new ObjectMapper()
                    .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

            WalletFile walletFile = lenientMapper.readValue(ETHERS_KEYSTORE_JSON, WalletFile.class);
            ECKeyPair keyPair = Wallet.decrypt(ETHERS_DEK_HEX, walletFile);

            String expectedAddress = ETHERS_ADDRESS.substring(2); // web3j Keys.getAddress()는 "0x" 없이 반환
            assertThat(Keys.getAddress(keyPair)).isEqualToIgnoringCase(expectedAddress);
            assertSignatureRecoversToAddress(keyPair, expectedAddress);
        }
    }


    private static void assertSignatureRecoversToAddress(ECKeyPair keyPair, String expectedAddress) throws Exception {
        byte[] message = "TIMO web3j spike".getBytes(StandardCharsets.UTF_8);
        Sign.SignatureData signature = Sign.signMessage(message, keyPair);

        BigInteger recoveredPublicKey = Sign.signedMessageToKey(message, signature);
        String recoveredAddress = Keys.getAddress(recoveredPublicKey);

        assertThat(recoveredAddress).isEqualToIgnoringCase(expectedAddress);
        assertThat(Credentials.create(keyPair).getAddress()).isEqualToIgnoringCase("0x" + expectedAddress);
    }
}
