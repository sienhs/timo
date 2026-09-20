package com.ssafy.timo.domain.notification.scheduler;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 상한 안에서 나눠 저장하는 도우미를 DB 없이 확인한다. 이미 받은 회원은 저장이 0 을 돌려주는 것으로 흉내 낸다. */
class SweepLimitsTest {

    /** 이미 알림을 받은 회원 집합을 가진 저장소 흉내. 새 회원만 세고 집합에 넣는다. */
    private static final class FakeRecorder {

        private final Set<Long> alreadyNotified = new HashSet<>();
        private final List<List<Long>> slices = new ArrayList<>();

        int record(List<Long> slice) {
            slices.add(List.copyOf(slice));
            int added = 0;
            for (Long memberId : slice) {
                if (alreadyNotified.add(memberId)) {
                    added++;
                }
            }
            return added;
        }
    }

    @Test
    @DisplayName("새로 저장한 수는 상한을 넘지 않는다")
    void neverExceedsMax() {
        FakeRecorder recorder = new FakeRecorder();

        int recorded = SweepLimits.recordUpTo(List.of(1L, 2L, 3L, 4L, 5L), 3, recorder::record);

        assertThat(recorded).isEqualTo(3);
        assertThat(recorder.alreadyNotified).hasSize(3);
    }

    @Test
    @DisplayName("상한이 대상보다 크면 전원에게 저장한다")
    void maxLargerThanTargets_recordsEveryone() {
        FakeRecorder recorder = new FakeRecorder();

        int recorded = SweepLimits.recordUpTo(List.of(1L, 2L, 3L), 500, recorder::record);

        assertThat(recorded).isEqualTo(3);
        assertThat(recorder.slices).containsExactly(List.of(1L, 2L, 3L));
    }

    @Test
    @DisplayName("앞쪽 회원이 이미 받았어도 상한이 찰 때까지 뒤쪽 새 회원을 이어서 저장한다")
    void skipsAlreadyNotifiedAndContinues() {
        FakeRecorder recorder = new FakeRecorder();
        recorder.alreadyNotified.addAll(List.of(1L, 2L));

        int recorded = SweepLimits.recordUpTo(List.of(1L, 2L, 3L, 4L, 5L), 2, recorder::record);

        assertThat(recorded).isEqualTo(2);
        assertThat(recorder.alreadyNotified).containsExactlyInAnyOrder(1L, 2L, 3L, 4L);
        // 처음에는 남은 상한(2)만큼, 그 조각이 전부 중복이라 하나도 못 채웠으므로 같은 크기로 이어 넘긴다.
        assertThat(recorder.slices).containsExactly(List.of(1L, 2L), List.of(3L, 4L));
    }

    @Test
    @DisplayName("전부 이미 받았으면 끝까지 훑고 0을 돌려준다")
    void everyoneAlreadyNotified_returnsZeroAfterScanningAll() {
        FakeRecorder recorder = new FakeRecorder();
        recorder.alreadyNotified.addAll(List.of(1L, 2L, 3L));

        int recorded = SweepLimits.recordUpTo(List.of(1L, 2L, 3L), 2, recorder::record);

        assertThat(recorded).isZero();
        assertThat(recorder.slices).containsExactly(List.of(1L, 2L), List.of(3L));
    }

    @Test
    @DisplayName("한 조각의 크기는 남은 상한을 넘지 않는다")
    void sliceSizeNeverExceedsRemaining() {
        FakeRecorder recorder = new FakeRecorder();

        SweepLimits.recordUpTo(List.of(1L, 2L, 3L, 4L, 5L, 6L, 7L), 5, recorder::record);

        assertThat(recorder.slices).allSatisfy(slice -> assertThat(slice.size()).isLessThanOrEqualTo(5));
    }

    @Test
    @DisplayName("대상이 없거나 상한이 0이면 저장을 부르지 않는다")
    void emptyOrZeroMax_callsNothing() {
        FakeRecorder recorder = new FakeRecorder();

        assertThat(SweepLimits.recordUpTo(List.of(), 5, recorder::record)).isZero();
        assertThat(SweepLimits.recordUpTo(List.of(1L, 2L), 0, recorder::record)).isZero();
        assertThat(recorder.slices).isEmpty();
    }
}
