package com.ssafy.timo.domain.goods.scheduler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.ssafy.timo.domain.goods.entity.GoodsUpload;
import com.ssafy.timo.domain.goods.repository.GoodsUploadRepository;
import com.ssafy.timo.global.config.goods.GoodsUploadProperties;
import com.ssafy.timo.global.storage.ImageStorage;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * 청소 배치. 무엇을 지울지는 저장소 쿼리가 정하고(굿즈 없는 티켓의 오래된 업로드분), 여기서는
 * <b>저장소에서 지운 뒤 대장에 적는</b> 순서와 스위치를 본다.
 *
 * <p>{@code TransactionTemplate} 은 목 트랜잭션 매니저를 끼운 실제 템플릿이라 콜백이 실제로 돈다.
 */
@ExtendWith(MockitoExtension.class)
class GoodsUploadCleanupSchedulerTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 21, 4, 0);
    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    @Mock
    private GoodsUploadRepository goodsUploadRepository;

    @Mock
    private ImageStorage imageStorage;

    @Mock
    private PlatformTransactionManager transactionManager;

    @Test
    @DisplayName("보존 기간이 지난 고아를 저장소에서 지우고 대장에는 상태만 남긴다")
    void deletesOrphansAndMarksLedger() {
        LocalDateTime cutoff = NOW.minusDays(7);
        given(goodsUploadRepository.findDeletable(cutoff, 2))
                .willReturn(List.of(upload(1L, "goods/7/42/a.png"), upload(2L, "goods/7/42/b.png")))
                .willReturn(List.of());

        int deleted = scheduler(true, 2, 10).cleanUp(NOW);

        assertThat(deleted).isEqualTo(2);
        verify(imageStorage).delete("goods/7/42/a.png");
        verify(imageStorage).delete("goods/7/42/b.png");
        verify(goodsUploadRepository).markDeleted(List.of(1L, 2L), NOW);
    }

    @Test
    @DisplayName("조각보다 적게 나오면 거기서 멈춘다 - 빈 조회를 한 번 더 하지 않는다")
    void stopsWhenChunkNotFull() {
        given(goodsUploadRepository.findDeletable(NOW.minusDays(7), 5))
                .willReturn(List.of(upload(1L, "goods/7/42/a.png")));

        assertThat(scheduler(true, 5, 10).cleanUp(NOW)).isEqualTo(1);

        verify(goodsUploadRepository).findDeletable(any(LocalDateTime.class), anyInt());
    }

    @Test
    @DisplayName("꺼 두면 아무것도 지우지 않는다")
    void doesNothingWhenDisabled() {
        scheduler(false, 2, 10).tick();

        verifyNoInteractions(goodsUploadRepository);
        verifyNoInteractions(imageStorage);
    }

    @Test
    @DisplayName("실행 중 예외가 나도 타이머를 죽이지 않는다 - 다음 주에 다시 돈다")
    void survivesFailure() {
        given(goodsUploadRepository.findDeletable(any(LocalDateTime.class), anyInt()))
                .willThrow(new RuntimeException("DB 접속 실패"));

        scheduler(true, 2, 10).tick();

        verify(goodsUploadRepository).findDeletable(any(LocalDateTime.class), anyInt());
        verifyNoInteractions(imageStorage);
    }

    private GoodsUploadCleanupScheduler scheduler(boolean enabled, int chunkSize, int maxChunks) {
        return new GoodsUploadCleanupScheduler(goodsUploadRepository, imageStorage, transactionManager,
                Clock.fixed(NOW.atZone(SEOUL).toInstant(), SEOUL),
                new GoodsUploadProperties(7, enabled), chunkSize, maxChunks);
    }

    private GoodsUpload upload(long id, String imageKey) {
        GoodsUpload upload = GoodsUpload.of(7L, 42L, imageKey);
        // id 는 저장 시점에 DB 가 채우는 값이라 팩터리로는 넣을 수 없다.
        ReflectionTestUtils.setField(upload, "id", id);
        return upload;
    }
}
