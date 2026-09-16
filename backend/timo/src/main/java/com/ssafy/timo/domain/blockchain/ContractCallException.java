package com.ssafy.timo.domain.blockchain;

/** 온체인 호출(읽기·쓰기)이 실패했을 때. 원인(revert, 네트워크 오류 등)은 메시지·cause로 구분한다. */
public class ContractCallException extends RuntimeException {

    public ContractCallException(String message) {
        super(message);
    }

    public ContractCallException(String message, Throwable cause) {
        super(message, cause);
    }
}
