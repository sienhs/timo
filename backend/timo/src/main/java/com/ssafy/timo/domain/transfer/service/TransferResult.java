package com.ssafy.timo.domain.transfer.service;

/**
 * 온체인 전송 성공 결과. 실패는 예외로 던지므로({@code TicketTransferService} 참고) 이 타입엔
 * 성공한 경우만 담는다.
 *
 * @param txHash 제3자가 체인에서 직접 검증할 수 있는 트랜잭션 해시
 */
public record TransferResult(String txHash) {
}
