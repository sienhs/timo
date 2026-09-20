package com.ssafy.timo.domain.wallet.crypto;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ssafy.timo.global.config.wallet.WalletProperties;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import java.util.HexFormat;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.web3j.crypto.Credentials;
import org.web3j.crypto.ECKeyPair;
import org.web3j.crypto.Keys;
import org.web3j.crypto.Wallet;
import org.web3j.crypto.WalletFile;

/**
 * 커스터디얼 지갑의 생성/복호화. blockchain/{@code custodialWallet.ts} 의 Java 이식이다.
 *
 * <p>지갑마다 새로 발급하는 DEK로 V3 keystore를 암호화하고, 그 DEK는 다시 {@link WalletProperties} 의 마스터키로 감싼다.
 * <p>원문 개인키·DEK는 메서드 실행 중에만 메모리에 존재했다가 사라지고, 저장소엔 두 겹으로 암호화된 값만 남는다.
 */
@Component
@RequiredArgsConstructor
public class CustodialWalletCrypto {

    private static final String DEK_CIPHER_TRANSFORMATION = "AES/GCM/NoPadding";
    private static final String AES_KEY_ALGORITHM = "AES";
    private static final int IV_LENGTH_BYTES = 12;
    private static final int AUTH_TAG_LENGTH_BITS = 128;
    private static final int DEK_LENGTH_BYTES = 32;

    private final WalletProperties walletProperties;
    private final SecureRandom secureRandom = new SecureRandom();

    /** keystore JSON을 읽을 때 알 수 없는 필드(예: 다른 도구가 남긴 확장 필드)가 있어도 막지 않는다. */
    private final ObjectMapper objectMapper = new ObjectMapper()
            .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    /** 새 EOA를 만들고, 이미 암호화된 상태로 돌려준다. 호출부는 원문 개인키·DEK를 볼 일이 없다. */
    public CustodialWalletMaterial create() {
        try {
            ECKeyPair keyPair = Keys.createEcKeyPair();
            // 사람이 손으로 옮겨 적는 경로가 없어(전부 프로그램적으로만 다룸) 체크섬(EIP-55)의
            // 오타 방지 효과가 의미 없다. 대소문자를 섞으면 오히려 어딘가에서 대소문자 구분
            // 비교(equals)를 실수로 썼을 때 "같은 주소인데 다르다고 나오는" 버그 여지만 생기므로,
            // 항상 소문자로 고정한다 - Credentials.getAddress()가 이미 소문자다.
            String address = Credentials.create(keyPair).getAddress();

            byte[] dek = new byte[DEK_LENGTH_BYTES];
            secureRandom.nextBytes(dek);

            WalletFile walletFile = Wallet.createStandard(HexFormat.of().formatHex(dek), keyPair);
            String encryptedKeystoreJson = objectMapper.writeValueAsString(walletFile);
            String wrappedDek = wrapDek(dek);

            return new CustodialWalletMaterial(address, encryptedKeystoreJson, wrappedDek);
        } catch (Exception e) {
            throw new WalletCryptoException("커스터디얼 지갑 생성에 실패했습니다.", e);
        }
    }

    /**
     * 저장된 산출물을 복호화해 서명 가능한 {@link Credentials} 로 되돌린다.
     * 마스터키가 다르거나 wrappedDek·keystore가 변조·손상됐으면 {@link WalletCryptoException} 이다.
     * 두 단계 다 인증 태그로 보호돼 있어 틀린 키로는 절대 우연히 성공하지 않는다.
     */
    public Credentials load(CustodialWalletMaterial material) {
        try {
            byte[] dek = unwrapDek(material.wrappedDek());
            WalletFile walletFile = objectMapper.readValue(material.encryptedKeystoreJson(), WalletFile.class);
            ECKeyPair keyPair = Wallet.decrypt(HexFormat.of().formatHex(dek), walletFile);

            return Credentials.create(keyPair);
        } catch (Exception e) {
            throw new WalletCryptoException("커스터디얼 지갑 복호화에 실패했습니다.", e);
        }
    }

    private String wrapDek(byte[] dek) throws GeneralSecurityException {
        byte[] iv = new byte[IV_LENGTH_BYTES];
        secureRandom.nextBytes(iv);

        Cipher cipher = Cipher.getInstance(DEK_CIPHER_TRANSFORMATION);
        cipher.init(Cipher.ENCRYPT_MODE, masterKeySpec(), new GCMParameterSpec(AUTH_TAG_LENGTH_BITS, iv));
        byte[] ciphertextAndTag = cipher.doFinal(dek);

        byte[] wrapped = new byte[iv.length + ciphertextAndTag.length];
        System.arraycopy(iv, 0, wrapped, 0, iv.length);
        System.arraycopy(ciphertextAndTag, 0, wrapped, iv.length, ciphertextAndTag.length);

        return Base64.getEncoder().encodeToString(wrapped);
    }

    private byte[] unwrapDek(String wrappedDek) throws GeneralSecurityException {
        byte[] wrapped = Base64.getDecoder().decode(wrappedDek);
        byte[] iv = Arrays.copyOfRange(wrapped, 0, IV_LENGTH_BYTES);
        byte[] ciphertextAndTag = Arrays.copyOfRange(wrapped, IV_LENGTH_BYTES, wrapped.length);

        Cipher cipher = Cipher.getInstance(DEK_CIPHER_TRANSFORMATION);
        cipher.init(Cipher.DECRYPT_MODE, masterKeySpec(), new GCMParameterSpec(AUTH_TAG_LENGTH_BITS, iv));

        return cipher.doFinal(ciphertextAndTag); // 마스터키가 다르면 AEADBadTagException
    }

    private SecretKeySpec masterKeySpec() {
        return new SecretKeySpec(HexFormat.of().parseHex(walletProperties.masterKey().expose()), AES_KEY_ALGORITHM);
    }
}
