package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.NotificationRecorder.Draft;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 양도한 티켓이 팔렸다는 알림을 판매자에게 남긴다.
 *
 * <p><b>{@code PurchaseService.purchase()} 가 체결 기록을 넣은 직후에 부른다.</b> 요구사항은 결제와 소유권
 * 이전까지 성공한 시점인데, 온체인 연동이 없는 지금은 소유권이 마지막 거래 행으로 계산되므로 체결 기록 INSERT 가
 * 곧 소유권 이전이다. 온체인 이전이 붙어 {@code TicketTrade.confirm()} 을 부르는 경로가 생기면 호출을 그 뒤로
 * 옮긴다. 키가 거래 id 라 옮겨도 같은 거래에 두 번 나가지 않는다.
 *
 * <p><b>거래를 만드는 트랜잭션 안에서 부른다.</b> 알림 저장이 거래와 같이 커밋되거나 같이 롤백돼야 한다. 푸시는 그
 * 트랜잭션이 커밋된 뒤에 나가므로 롤백된 거래의 알림이 기기에 뜨지 않는다. 트랜잭션 밖에서 부르면 이
 * 메서드가 스스로 트랜잭션을 열어 저장까지는 하지만, 거래와 알림이 따로 커밋되어 하나만 남을 수 있다.
 *
 * <p>같은 거래로 여러 번 불러도 알림은 한 번만 남고 푸시도 한 번만 나간다. 확정 처리가 재시도돼도 판매자가
 * 같은 알림을 두 번 받지 않는다.
 *
 * <p>거래 엔티티를 받지 않고 값만 받는다. 알림이 양도 도메인의 타입에 묶이지 않게 하려는 것이다. 판매자와
 * 구매자는 서로를 알 수 없어야 하므로 구매자에 대한 정보는 받지도 않는다.
 */
@Service
@RequiredArgsConstructor
public class ListingSoldNotifier {

    private final NotificationRecorder notificationRecorder;

    /**
     * 판매 완료를 판매자에게 알린다.
     *
     * @param sellerMemberId 매물을 올린 판매자. 알림을 받는 사람이다
     * @param tradeId        체결된 거래. 알림에서 거래 상세로 이동하고 중복 방지의 기준이 된다
     * @param concertTitle   팔린 티켓의 공연명
     * @return 새로 저장했으면 true. 이미 보낸 거래이거나 회원이 없으면 false
     */
    @Transactional
    public boolean notifySold(Long sellerMemberId, Long tradeId, String concertTitle) {
        return notificationRecorder.record(Draft.of(
                sellerMemberId,
                NotificationType.LISTING_SOLD,
                NotificationMessages.listingSold(concertTitle),
                tradeId,
                NotificationType.LISTING_SOLD.tradeKey(tradeId)));
    }
}
