package com.ssafy.timo.domain.wallet.crypto;

import com.ssafy.timo.global.exception.BusinessException;
import com.ssafy.timo.global.exception.GlobalExceptionHandler;

/**
 * 커스터디얼 지갑 암복호화(키페어 생성, keystore 암복호화, DEK wrap/unwrap) 실패.
 *
 * <p>{@link BusinessException} 을 상속하지 않는다. 그 계층은 클라이언트가 구분해서 반응할 수
 * 있는 정상 흐름의 실패(좌석 없음, 닉네임 중복 등)를 위한 것이라 warn 으로만 남기는데, 이
 * 예외는 마스터키 설정 오류·데이터 변조 같은 사고라 {@link GlobalExceptionHandler} 의
 * 처리되지 않은 예외 경로(스택트레이스를 error 로 남기고 500 응답)를 그대로 타야 한다.
 */
public class WalletCryptoException extends RuntimeException {

    public WalletCryptoException(String message, Throwable cause) {
        super(message, cause);
    }
}
