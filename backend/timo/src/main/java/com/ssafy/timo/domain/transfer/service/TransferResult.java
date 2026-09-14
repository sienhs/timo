package com.ssafy.timo.domain.transfer.service;

/**
 * 온체인 전송 시도의 결과.
 *
 * <p>{@code txHash} 는 제3자가 체인에서 직접 검증할 수 있는 유일한 근거다. 전송을 보내지도 못하고
 * 실패한 경우에는 해시가 없으므로 비어 있을 수 있다.
 *
 * <p><b>이 모양은 확정이 아니다.</b> {@code TicketTransferService} 주석의 제약을 함께 본다.
 *
 * @param success 온체인 전송을 보내는 데 성공했는지
 * @param txHash  트랜잭션 해시. 보내지 못했으면 {@code null}
 */
public record TransferResult(boolean success, String txHash) {

    public static TransferResult sent(String txHash) {
        return new TransferResult(true, txHash);
    }

    public static TransferResult failed() {
        return new TransferResult(false, null);
    }
}
