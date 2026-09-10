package com.ssafy.timo.domain.wallet.crypto;

/**
 * 새로 생성된 커스터디얼 지갑의 암호화된 산출물.
 *
 * <p>신원(어느 회원의 지갑인지)은 담지 않는다.
 *
 * <p>{@code Wallet} 엔티티가 {@code member_id} 로 이미 갖고 있을 정보라, 순수 크립토 값 객체에 중복으로 두지 않는다.
 *
 * @param address               지갑의 이더리움 주소 (소문자 고정, {@code 0x} 접두)
 * @param encryptedKeystoreJson DEK로 암호화한 V3 keystore JSON
 * @param wrappedDek            마스터키로 감싼(wrap) DEK
 */
public record CustodialWalletMaterial(String address, String encryptedKeystoreJson, String wrappedDek) {
}
