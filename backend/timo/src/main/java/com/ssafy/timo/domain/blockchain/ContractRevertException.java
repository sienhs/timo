package com.ssafy.timo.domain.blockchain;

/** 트랜잭션이 체인에서 revert된 경우. 재시도해도 같은 이유로 또 거부되므로 나머지 실패(전송 실패·네트워크 오류)와 구분해 던진다. */
public class ContractRevertException extends ContractCallException {

    public ContractRevertException(String message) {
        super(message);
    }
}
