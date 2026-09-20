package com.ssafy.timo.domain.notification.entity;

/**
 * 같은 공연에 시점별로 나가는 알림의 시점. 이름이 곧 중복 방지 키에 들어가는 구분자다
 * ({@code CONCERT_OPEN_D7:concert=12} 의 {@code D7}). 이름을 바꾸면 이미 나간 알림과 키가 달라져
 * 같은 알림이 한 번 더 나가므로 함부로 바꾸지 않는다.
 *
 * <p>문구는 시점마다 문장 구조 자체가 달라 이 시점에 라벨을 붙여 템플릿에 끼워 넣는 방식으로는 만들 수
 * 없다. 대신 {@link NotificationType#templateFor(NotificationPhase)} 가 (종류, 시점)마다 완성된
 * 한 줄 템플릿을 따로 갖는다. 예매 오픈은 D-7 · D-1 · H-1 만, 공연 일정은 D-7 · D-1 · D-0 만 쓴다.
 * 어느 종류가 어느 시점을 쓰는지는 스윕이 정한다.
 */
public enum NotificationPhase {
    D7,
    D1,
    D0,
    H1
}
