package com.ssafy.timo.domain.goods.repository;

import com.ssafy.timo.domain.goods.entity.GoodsUpload;
import com.ssafy.timo.domain.goods.entity.GoodsUploadStatus;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/** 업로드 대장 저장소. 쓰는 쪽은 업로드 API 와 청소 배치 둘뿐이다. */
@Repository
public interface GoodsUploadRepository extends JpaRepository<GoodsUpload, Long> {

    /**
     * 지울 대상 - 기준 시각보다 오래됐고 아직 굿즈로 이어지지 않은 업로드 이미지. 지우는 것은 그 이미지이고
     * 티켓이 아니다 - 티켓은 무엇을 살릴지 가르는 기준으로만 쓴다.
     *
     * <p>{@code not exists} 로 굿즈 유무를 보므로 굿즈가 하나라도 생긴 티켓은 그 티켓의 업로드가
     * 전부 빠진다(티켓 단위 판정, {@link GoodsUpload} 주석 참고).
     *
     * <p>한 번에 다 가져오지 않는다. 조각마다 트랜잭션을 따로 열어 지우려고 {@code limit} 을 받는다.
     */
    @Query(value = """
            select *
              from goods_upload u
             where u.status = 'UPLOADED'
               and u.created_at < :cutoff
               and not exists (select 1 from goods g where g.ticket_id = u.ticket_id)
             order by u.goods_upload_id
             limit :limit
            """,
            nativeQuery = true)
    List<GoodsUpload> findDeletable(@Param("cutoff") LocalDateTime cutoff, @Param("limit") int limit);

    /**
     * 저장소에서 지운 것을 대장에 적는다. 행을 지우지 않는 이유는 {@link GoodsUpload} 주석에 있다.
     *
     * <p>벌크 업데이트라 {@code updated_at} 은 감사(auditing)가 채우지 않는다. 대장에서 그 값을 읽는
     * 곳이 없어 그대로 둔다 - 지운 시각은 {@code deleted_at} 이 들고 있다.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update GoodsUpload u
               set u.status = com.ssafy.timo.domain.goods.entity.GoodsUploadStatus.DELETED,
                   u.deletedAt = :deletedAt
             where u.id in :ids
            """)
    int markDeleted(@Param("ids") Collection<Long> ids, @Param("deletedAt") LocalDateTime deletedAt);

    /**
     * 이 key 들 중 이미 지워진 것의 수. 굿즈 생성이 깨진 이미지를 가리키지 않는지 볼 때 쓴다.
     *
     * <p>대장에 없는 key 는 세지 않는다. 앱이 지어낸 값이라면 그 key 로 열리는 객체가 없을 뿐이고,
     * 그것까지 막으려면 레이어 안의 key 도 봐야 하는데 서버는 그 JSON 을 해석하지 않는다.
     */
    @Query("""
            select count(u)
              from GoodsUpload u
             where u.imageKey in :imageKeys
               and u.status = :status
            """)
    long countByStatus(@Param("imageKeys") Collection<String> imageKeys,
                       @Param("status") GoodsUploadStatus status);
}
