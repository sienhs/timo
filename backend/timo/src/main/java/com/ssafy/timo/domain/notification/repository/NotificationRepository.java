package com.ssafy.timo.domain.notification.repository;

import com.ssafy.timo.domain.notification.dto.UnreadCountRow;
import com.ssafy.timo.domain.notification.entity.Notification;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    /**
     * 알림을 넣는다. 같은 회원에게 같은 {@code dedupKey} 가 이미 있으면 아무것도 하지 않는다.
     *
     * <p>반환값이 곧 "이번에 새로 넣었는가"다. 1 이면 새 알림이라 푸시를 보내고, 0 이면 이미 있던
     * 알림이라 보내지 않는다. 스케줄러가 같은 창을 여러 번 훑어도 알림이 한 번만 나가는 근거다.
     *
     * <p>JPA {@code save()} 로 바꾸지 않는다. 유니크 위반이 예외가 되면 호출한 트랜잭션이
     * rollback-only 가 되어, 같은 트랜잭션에 있던 결제까지 롤백된다.
     *
     * <p>{@code INSERT IGNORE} 는 유니크 위반뿐 아니라 다른 오류도 경고로 낮춰 삼킨다. 그래서
     * 다음 둘은 예외 없이 조용히 벌어진다.
     * <ul>
     *   <li>회원이 없으면 외래 키 위반이 무시되어 0 이 돌아온다. 중복과 구별되지 않는다.</li>
     *   <li>{@code body} 가 500자를 넘으면 잘려서 들어간다. 문구 조립기가 길이를 지켜야 한다.</li>
     * </ul>
     *
     * <p>네이티브 쿼리는 JPA Auditing 을 거치지 않으므로 생성·수정 시각을 직접 넣는다.
     * 호출부가 {@code Clock} 으로 정한 시각을 {@code now} 로 준다.
     */
    @Modifying
    @Query(value = """
            insert ignore into notification
                (member_id, type, body, link_type, link_id, dedup_key, created_at, updated_at)
            values
                (:memberId, :type, :body, :linkType, :linkId, :dedupKey, :now, :now)
            """, nativeQuery = true)
    int insertIgnore(@Param("memberId") Long memberId,
                     @Param("type") String type,
                     @Param("body") String body,
                     @Param("linkType") String linkType,
                     @Param("linkId") Long linkId,
                     @Param("dedupKey") String dedupKey,
                     @Param("now") LocalDateTime now);

    /**
     * 방금 넣은 알림의 id. {@link #insertIgnore} 가 id 를 돌려주지 않아서 필요하다. 유니크 인덱스
     * {@code (member_id, dedup_key)} 로 한 행만 찾는다.
     */
    @Query("select n.id from Notification n where n.member.id = :memberId and n.dedupKey = :dedupKey")
    Optional<Long> findIdByMemberIdAndDedupKey(@Param("memberId") Long memberId,
                                               @Param("dedupKey") String dedupKey);

    /**
     * 내 알림을 최신순으로, {@code cursor} 보다 오래된 것만. {@code notification_id} 가 IDENTITY 로 늘어나
     * 므로 이 id 하나가 정렬과 커서를 겸한다. {@code (member_id, notification_id desc)} 인덱스를 탄다.
     *
     * <p>다음 페이지가 있는지 알려면 한 건 더 읽어야 해서 호출부가 {@code size + 1} 을 요청한다.
     * {@code member_id} 조건은 뺄 수 없다. 없으면 남의 알림까지 읽힌다.
     */
    @Query("""
            select n
              from Notification n
             where n.member.id = :memberId
               and n.id < :cursor
             order by n.id desc
            """)
    List<Notification> findPageOfMember(@Param("memberId") Long memberId,
                                        @Param("cursor") Long cursor,
                                        Pageable pageable);

    /**
     * 기준 시각보다 먼저 만들어진 알림을 오래된 것부터 최대 {@code batchSize} 건 지운다. 읽었는지는 보지
     * 않는다. 지운 개수를 돌려주며, 이 값이 {@code batchSize} 보다 작으면 더 지울 것이 없다는 뜻이다.
     *
     * <p>한 번에 다 지우지 않고 나눠 지우는 이유는 대량 삭제가 오래 행을 잠가 알림함 조회와 새 알림 저장을
     * 막기 때문이다. 호출부가 조각마다 트랜잭션을 따로 연다.
     *
     * <p>{@code idx_notification_created} 를 탄다. 정렬을 명시한 것은 {@code LIMIT} 만 있으면 어떤 행이
     * 지워질지 정해지지 않아 복제 환경에서 안전하지 않기 때문이다.
     */
    @Modifying
    @Query(value = """
            delete from notification
             where created_at < :cutoff
             order by created_at, notification_id
             limit :batchSize
            """, nativeQuery = true)
    int deleteOlderThan(@Param("cutoff") LocalDateTime cutoff, @Param("batchSize") int batchSize);

    long countByMember_IdAndReadAtIsNull(Long memberId);

    /**
     * 여러 회원의 안 읽은 개수를 한 번에. 푸시에 실을 배지 숫자를 회원마다 따로 세면 수백 번의 쿼리가
     * 되므로 묶어서 센다. {@code (member_id, read_at)} 인덱스를 탄다. 안 읽은 알림이 없는 회원은 결과에
     * 없다.
     */
    @Query("""
            select n.member.id as memberId, count(n) as unreadCount
              from Notification n
             where n.member.id in :memberIds and n.readAt is null
             group by n.member.id
            """)
    List<UnreadCountRow> countUnreadByMemberIds(@Param("memberIds") Collection<Long> memberIds);

    boolean existsByIdAndMember_Id(Long id, Long memberId);

    /**
     * 읽음 처리. 아직 안 읽은 내 알림만 갱신하므로 이미 읽은 알림의 읽은 시각은 처음 값을 유지한다.
     * 영향 행 수가 0 이면 "이미 읽음" 이거나 "없거나 남의 것" 이라 호출부가 가려야 한다.
     *
     * <p>벌크 갱신은 JPA Auditing 을 거치지 않으므로 수정 시각을 직접 넣는다.
     */
    @Modifying
    @Query("""
            update Notification n
               set n.readAt = :now, n.updatedAt = :now
             where n.id = :id and n.member.id = :memberId and n.readAt is null
            """)
    int markRead(@Param("id") Long id, @Param("memberId") Long memberId, @Param("now") LocalDateTime now);

    /**
     * 내 안 읽은 알림을 전부 읽음으로 바꾼다. 이미 읽은 알림은 건드리지 않으므로 읽은 시각이 그대로다.
     * 영향 행 수를 돌려주며, 이는 곧 이번에 새로 읽음 처리한 개수다. 안 읽은 알림이 없어도 0 을 돌려줄 뿐
     * 실패가 아니다.
     *
     * <p>벌크 갱신은 JPA Auditing 을 거치지 않으므로 수정 시각을 직접 넣는다.
     */
    @Modifying
    @Query("""
            update Notification n
               set n.readAt = :now, n.updatedAt = :now
             where n.member.id = :memberId and n.readAt is null
            """)
    int markAllRead(@Param("memberId") Long memberId, @Param("now") LocalDateTime now);
}
