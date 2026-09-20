package com.ssafy.timo.domain.notification.scheduler;

import java.util.List;
import java.util.function.ToIntFunction;

/**
 * 스윕이 처리 상한 안에서 대상들에게 알림을 나눠 저장하도록 돕는다. 대상이 많을 때 상한을 넘지 않으면서 이미
 * 알림을 받은 대상을 건너뛰고 새로 받을 대상까지 이어 가는 방법이 한 가지라, 스윕마다 다시 짜지 않게 모아
 * 둔다. 대상은 회원 id 일 수도, 회원마다 내용이 다른 알림 초안일 수도 있다.
 */
final class SweepLimits {

    private SweepLimits() {
    }

    /**
     * 목록을 앞에서부터 나눠 저장하되, 새로 저장한 알림이 {@code max} 개를 넘지 않게 한다.
     *
     * <p>한 번에 넘기는 개수를 남은 상한 이하로 잡아서 상한을 넘을 수가 없다. 넘긴 것 중 일부가 이미 알림을
     * 받은 상태(중복)면 새로 저장된 수가 그만큼 모자라므로, 남은 만큼 다음 대상들을 이어서 넘긴다. 그래서
     * 목록의 순서가 주기마다 달라져도 앞쪽 대상들이 자리를 차지해 뒤쪽 대상이 굶는 일이 없다.
     *
     * @param record 대상 묶음을 저장하고 새로 저장된 수를 돌려주는 동작
     * @return 새로 저장한 알림 수. {@code max} 이하다
     */
    static <T> int recordUpTo(List<T> targets, int max, ToIntFunction<List<T>> record) {
        int recorded = 0;
        int next = 0;
        while (next < targets.size() && recorded < max) {
            int sliceSize = Math.min(max - recorded, targets.size() - next);
            List<T> slice = targets.subList(next, next + sliceSize);
            recorded += record.applyAsInt(slice);
            next += sliceSize;
        }
        return recorded;
    }
}
