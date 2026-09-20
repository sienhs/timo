package com.ssafy.timo.domain.blockchain;

/** 온체인 호출(읽기·쓰기)이 실패했을 때. revert는 하위 타입 {@link ContractRevertException}, 그 외는 이 타입 그대로. */
public class ContractCallException extends RuntimeException {

    public ContractCallException(String message) {
        super(message);
    }

    public ContractCallException(String message, Throwable cause) {
        super(message, cause);
    }
}
