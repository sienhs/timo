package com.ssafy.timo.global.config.wallet;

import com.ssafy.timo.domain.wallet.crypto.MasterKey;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 커스터디얼 지갑의 마스터키 설정.
 *
 * <p>지갑별 DEK(데이터 암호화 키)를 암호화하고 복호화하는 데 사용한다. 환경별로 다른 키를 사용하므로 application-{profile}.yml에서 설정한다.
 * <p>형식 검증과 원문 노출 방지는 전부 {@link MasterKey} 가 맡는다. 기존 custodialWallet.ts와 동일하게 64자리 16진수(32바이트) 형식을 검증한다.
 * <p>현재 프로토타입은 설정값으로 키를 주입한다. 운영 환경에서는 KMS 등 외부 키 관리 시스템을 사용하도록 전환이 필요하다.
 *
 * @param masterKey DEK 암복호화에 사용하는 마스터키
 */

@ConfigurationProperties(prefix = "wallet")
public record WalletProperties(MasterKey masterKey) {
}
