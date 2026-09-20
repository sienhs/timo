package com.ssafy.timo.domain.wallet.crypto;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ssafy.timo.global.config.wallet.WalletProperties;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.web3j.crypto.Credentials;
import org.web3j.crypto.Sign;

/**
 * {@link CustodialWalletCrypto} 를 검증한다. Spring 컨텍스트는 띄우지 않는다 -
 * {@link WalletProperties} 를 직접 만들어 넘기는 것만으로 충분하다.
 */
class CustodialWalletCryptoTest {

    private static final String MASTER_KEY_HEX = "a".repeat(64);
    private static final String OTHER_MASTER_KEY_HEX = "b".repeat(64);

    private final CustodialWalletCrypto crypto = cryptoWith(MASTER_KEY_HEX);

    @Test
    @DisplayName("소문자 hex 주소 형식의 지갑을 생성한다")
    void create_producesALowercaseHexAddress() {
        CustodialWalletMaterial material = crypto.create();

        assertThat(material.address()).matches("^0x[0-9a-f]{40}$");
    }

    @Test
    @DisplayName("호출할 때마다 다른 주소를 생성한다")
    void create_generatesADifferentAddressEachTime() {
        assertThat(crypto.create().address()).isNotEqualTo(crypto.create().address());
    }

    @Test
    @DisplayName("같은 마스터키를 쓰더라도 지갑마다 다른 wrappedDek를 생성한다")
    void create_wrapsADifferentRandomDekEvenUnderTheSameMasterKey() {
        assertThat(crypto.create().wrappedDek()).isNotEqualTo(crypto.create().wrappedDek());
    }

    @Test
    @DisplayName("생성한 지갑을 그대로 복호화하면 같은 주소로 돌아온다")
    void createThenLoad_roundTripsToTheSameAddress() {
        CustodialWalletMaterial material = crypto.create();

        Credentials credentials = crypto.load(material);

        assertThat(credentials.getAddress()).isEqualToIgnoringCase(material.address());
    }

    @Test
    @DisplayName("복호화한 지갑으로 실제 서명이 가능하다 - 진짜 그 개인키를 들고 있다는 증거")
    void loadedWallet_canActuallySign() throws Exception {
        CustodialWalletMaterial material = crypto.create();
        Credentials credentials = crypto.load(material);

        byte[] message = "TIMO wallet crypto test".getBytes(StandardCharsets.UTF_8);
        Sign.SignatureData signature = Sign.signMessage(message, credentials.getEcKeyPair());
        BigInteger recoveredPublicKey = Sign.signedMessageToKey(message, signature);

        assertThat("0x" + org.web3j.crypto.Keys.getAddress(recoveredPublicKey))
                .isEqualToIgnoringCase(material.address());
    }

    @Test
    @DisplayName("생성할 때와 다른 마스터키로 복호화하면 실패한다")
    void load_withAWrongMasterKey_fails() {
        CustodialWalletMaterial material = crypto.create();
        CustodialWalletCrypto cryptoWithOtherMasterKey = cryptoWith(OTHER_MASTER_KEY_HEX);

        assertThatThrownBy(() -> cryptoWithOtherMasterKey.load(material))
                .isInstanceOf(WalletCryptoException.class);
    }

    @Test
    @DisplayName("wrappedDek가 변조되면 복호화가 실패한다")
    void load_withATamperedWrappedDek_fails() {
        CustodialWalletMaterial material = crypto.create();
        String tamperedWrappedDek = flipLastByte(material.wrappedDek());
        CustodialWalletMaterial tampered =
                new CustodialWalletMaterial(material.address(), material.encryptedKeystoreJson(), tamperedWrappedDek);

        assertThatThrownBy(() -> crypto.load(tampered)).isInstanceOf(WalletCryptoException.class);
    }

    @Test
    @DisplayName("keystore가 변조되면 복호화가 실패한다")
    void load_withATamperedKeystore_fails() throws Exception {
        CustodialWalletMaterial material = crypto.create();
        String tamperedKeystoreJson = tamperCiphertext(material.encryptedKeystoreJson());
        CustodialWalletMaterial tampered =
                new CustodialWalletMaterial(material.address(), tamperedKeystoreJson, material.wrappedDek());

        assertThatThrownBy(() -> crypto.load(tampered)).isInstanceOf(WalletCryptoException.class);
    }

    @Test
    @DisplayName("실제 자금이 걸릴 지갑이므로 가벼운 scrypt(LIGHT)가 아니라 STANDARD 비용으로 keystore를 만든다")
    void create_usesStandardScryptCostNotLight() throws Exception {
        CustodialWalletMaterial material = crypto.create();

        JsonNode kdfParams = new ObjectMapper().readTree(material.encryptedKeystoreJson())
                .get("crypto").get("kdfparams");

        assertThat(kdfParams.get("n").asInt()).isEqualTo(262144);
    }

    private CustodialWalletCrypto cryptoWith(String masterKeyHex) {
        return new CustodialWalletCrypto(new WalletProperties(MasterKey.of(masterKeyHex)));
    }

    private String flipLastByte(String base64) {
        byte[] bytes = Base64.getDecoder().decode(base64);
        bytes[bytes.length - 1] ^= 0xFF;
        return Base64.getEncoder().encodeToString(bytes);
    }

    private String tamperCiphertext(String keystoreJson) throws Exception {
        String ciphertext = new ObjectMapper().readTree(keystoreJson).get("crypto").get("ciphertext").asText();
        char flippedFirstChar = ciphertext.charAt(0) == '0' ? '1' : '0';
        String tamperedCiphertext = flippedFirstChar + ciphertext.substring(1);

        return keystoreJson.replace(ciphertext, tamperedCiphertext);
    }
}
