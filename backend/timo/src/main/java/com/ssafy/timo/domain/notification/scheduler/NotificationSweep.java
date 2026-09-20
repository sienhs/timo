package com.ssafy.timo.domain.notification.scheduler;

import java.time.LocalDateTime;

/**
 * 시간에 맞춰 나가는 알림 한 종류를 찾아 저장하는 단위. 입장 가능, 예매 오픈 안내, 공연 일정, 양도 매물이
 * 각각 하나씩 구현한다.
 *
 * <p>구현이 지켜야 하는 것들.
 * <ul>
 *   <li><b>같은 창을 여러 번 훑어도 결과가 같아야 한다.</b> 스케줄러가 매 주기마다 부르고 놓친 발송을
 *       보정 구간만큼 다시 훑기 때문이다. 이미 나간 알림은 {@code NotificationRecorder} 의 중복 방지가
 *       막으므로, 구현은 저장만 하면 되고 "보냈는지" 를 따로 기억하지 않는다.</li>
 *   <li><b>알림은 반드시 {@code NotificationRecorder} 로 저장한다.</b> 중복 방지와 푸시 발송이 그 문에
 *       있다. 직접 저장하면 둘 다 빠진다.</li>
 *   <li><b>트랜잭션을 직접 열지 않는다.</b> 스케줄러가 스윕마다 트랜잭션 하나를 열어 준다. 던진 예외는
 *       그 스윕의 저장을 통째로 되돌리고 다른 스윕에는 영향이 없다.</li>
 *   <li><b>시각은 받은 {@code now} 만 쓴다.</b> 시스템 시계를 직접 읽으면 한 주기 안에서 스윕마다 기준이
 *       달라지고, 테스트가 시각을 고정할 수 없다.</li>
 * </ul>
 */
public interface NotificationSweep {

    /** 로그와 진단에 쓰는 이름. */
    String name();

    /**
     * 지금 보낼 알림을 찾아 저장한다.
     *
     * @param now   이번 주기의 기준 시각
     * @param limit 이번 주기에 새로 저장할 수 있는 알림의 최대 개수. 다 채우면 멈추고 남은 것은 다음
     *              주기에 이어서 처리한다
     * @return 새로 저장한 알림 수
     */
    int run(LocalDateTime now, int limit);
}
