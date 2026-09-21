package com.ssafy.timo.domain.goods.scheduler;

import com.ssafy.timo.domain.goods.entity.GoodsUpload;
import com.ssafy.timo.domain.goods.repository.GoodsUploadRepository;
import com.ssafy.timo.global.config.goods.GoodsUploadProperties;
import com.ssafy.timo.global.storage.ImageStorage;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 굿즈로 이어지지 않은 업로드 이미지를 지운다. 제작하다 그만둔 사람이 남긴 것들이다.
 *
 * <p>지우는 것은 저장소에 올라간 <b>이미지</b>다. 티켓과 굿즈는 건드리지 않는다.
 *
 * <p><b>무엇을 살릴지는 티켓 단위로 판정한다.</b> 그 티켓에 굿즈가 있으면 그 티켓으로 올린 이미지는
 * 전부 살린다. 굿즈의
 * {@code personLayers} 를 열어 어느 key 가 실제로 쓰였는지 보지 않으므로, 제작 중 버리고 다시 올린
 * 시도분도 같이 살아남는다. 그것이 이 근사의 값이고 — 대신 <b>쓰고 있는 이미지를 지울 위험이 없다.</b>
 *
 * <p>주 1회, 보존 기간은 {@link GoodsUploadProperties} 가 정한다(기본 7일). 고아는 최대
 * 보존기간 + 1주를 살다 사라지는데, 미완성 제작분이라 그 지연은 비용이 무시할 만하다.
 *
 * <p><b>저장소에서 지운 뒤 대장에 적는다.</b> 순서가 반대면 "지웠다고 적혀 있는데 객체는 남은" 행이
 * 생기고 그 객체를 다시 찾을 방법이 없다. 이 순서로 하면 사이에서 끊겨도 다음 주에 같은 행이 다시
 * 잡혀 다시 지운다 — {@code ImageStorage.delete} 는 없는 key 에도 조용하므로 해가 없다.
 *
 * <p>인스턴스가 여러 대여도 락을 걸지 않는다. 같은 행을 둘이 집으면 삭제가 두 번 나갈 뿐이고 그
 * 계약이 조용하다. 인스턴스를 늘릴 때 다시 볼 것.
 */
@Slf4j
@Component
public class GoodsUploadCleanupScheduler {

    /** 한 번에 집는 행 수. 대량 삭제가 오래 행을 잠그지 않도록 조각마다 트랜잭션을 연다. */
    static final int CHUNK_SIZE = 500;

    /** 한 번의 실행에서 처리하는 조각 수의 상한. 밀린 양은 다음 주에 이어서 지운다. */
    static final int MAX_CHUNKS_PER_RUN = 100;

    private final GoodsUploadRepository goodsUploadRepository;
    private final ImageStorage imageStorage;
    private final TransactionTemplate transactionTemplate;
    private final Clock clock;
    private final GoodsUploadProperties properties;
    private final int chunkSize;
    private final int maxChunksPerRun;

    @Autowired
    public GoodsUploadCleanupScheduler(GoodsUploadRepository goodsUploadRepository,
                                       ImageStorage imageStorage,
                                       PlatformTransactionManager transactionManager,
                                       Clock clock,
                                       GoodsUploadProperties properties) {
        this(goodsUploadRepository, imageStorage, transactionManager, clock, properties,
                CHUNK_SIZE, MAX_CHUNKS_PER_RUN);
    }

    /** 테스트가 조각 크기와 상한을 줄여 쓰려고 연 생성자. */
    GoodsUploadCleanupScheduler(GoodsUploadRepository goodsUploadRepository,
                                ImageStorage imageStorage,
                                PlatformTransactionManager transactionManager,
                                Clock clock,
                                GoodsUploadProperties properties,
                                int chunkSize,
                                int maxChunksPerRun) {
        this.goodsUploadRepository = goodsUploadRepository;
        this.imageStorage = imageStorage;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.clock = clock;
        this.properties = properties;
        this.chunkSize = chunkSize;
        this.maxChunksPerRun = maxChunksPerRun;
    }

    /** 매주 월요일 새벽 4시. 서울 기준이다. 꺼져 있으면({@code cleanup-enabled: false}) 아무것도 하지 않는다. */
    @Scheduled(cron = "0 0 4 * * MON", zone = "Asia/Seoul")
    public void tick() {
        if (!properties.cleanupEnabled()) {
            return;
        }
        try {
            cleanUp(LocalDateTime.now(clock));
        } catch (Exception e) {
            // 다음 주에 다시 돈다. 지우지 못한 것은 그대로 남아 있을 뿐이다.
            log.error("굿즈 업로드 청소 실패", e);
        }
    }

    /**
     * 아직 굿즈로 이어지지 않은 오래된 업로드 이미지를 지운다. 타이머 없이 부를 수 있어 테스트가 쓴다.
     *
     * @return 지운 이미지 수
     */
    public int cleanUp(LocalDateTime now) {
        LocalDateTime cutoff = now.minusDays(properties.uploadRetentionDays());

        int total = 0;
        for (int chunk = 0; chunk < maxChunksPerRun; chunk++) {
            List<GoodsUpload> deletable = goodsUploadRepository.findDeletable(cutoff, chunkSize);
            if (deletable.isEmpty()) {
                break;
            }

            deletable.forEach(upload -> imageStorage.delete(upload.getImageKey()));

            List<Long> ids = deletable.stream().map(GoodsUpload::getId).toList();
            transactionTemplate.execute(status -> goodsUploadRepository.markDeleted(ids, now));

            total += deletable.size();
            if (deletable.size() < chunkSize) {
                break; // 더 지울 것이 없다.
            }
        }

        if (total > 0) {
            log.info("굿즈 업로드 청소 (deleted={}, cutoff={})", total, cutoff);
        }
        return total;
    }
}
