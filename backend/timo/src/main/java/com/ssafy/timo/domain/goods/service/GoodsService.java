package com.ssafy.timo.domain.goods.service;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.goods.dto.CreateGoodsCommand;
import com.ssafy.timo.domain.goods.dto.GoodsCreateResult;
import com.ssafy.timo.domain.goods.entity.Goods;
import com.ssafy.timo.domain.goods.entity.GoodsUploadStatus;
import com.ssafy.timo.domain.goods.exception.GoodsAlreadyExistsException;
import com.ssafy.timo.domain.goods.exception.GoodsImageDeletedException;
import com.ssafy.timo.domain.goods.repository.GoodsRepository;
import com.ssafy.timo.domain.goods.repository.GoodsUploadRepository;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 굿즈 생성.
 *
 * <p>순서대로 가린다 — 지금 내 티켓인가(아니면 404), 입장 완료인가(409), 레이어가 규칙에 맞는가(400),
 * 이미 만들었는가(같은 멱등 키면 기존 것을 200 으로, 다른 키면 409). 다 통과하면 공연 스냅샷을 채워
 * 저장한다. 수정·삭제는 없다.
 *
 * <p><b>동시 요청은 {@code uk_goods_ticket} 이 가른다.</b> 두 요청이 동시에 "굿즈 없음" 을 읽고 둘 다
 * INSERT 하면 하나는 유니크 위반으로 실패한다. 그 실패를 잡아 위 규칙으로 <b>다시 판정</b>해야 재시도한
 * 앱이 200 을 받는다. 그래서 {@code @Transactional} 대신 {@link TransactionTemplate} 을 쓴다 —
 * 위반이 난 트랜잭션은 이미 롤백 대상이라 그 안에서는 다시 읽을 수 없고, 롤백이 끝난 뒤 새 트랜잭션에서
 * 읽어야 한다.
 *
 * <p><b>이미지는 이 메서드가 받지 않는다.</b> 앱이 먼저 업로드 API 로 올리고
 * ({@link GoodsUploadService}) 받은 key 를 요청에 실어 온다. 그래서 요청 바디가 곧
 * {@link CreateGoodsCommand} 이고, 이 메서드는 저장소를 건드리지 않는다 — 티켓 판정은 업로드 쪽에서
 * 이미 한 번 끝났고 여기서 한 번 더 한다({@link GoodsTicketGuard}).
 *
 * <p>앱이 써넣은 key 는 <b>이미 지워진 것만</b> 가린다. key 는 UUID 라 추측할 수 없고 남의 굿즈
 * 상세는 404 라 남의 key 를 알아낼 경로가 사실상 없다. 레이어 안의 key 는 보지 않는다 — 서버가 그
 * JSON 구조를 해석하지 않는다는 규칙 그대로다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GoodsService {

    private final GoodsRepository goodsRepository;
    private final GoodsUploadRepository goodsUploadRepository;
    private final MemberRepository memberRepository;
    private final GoodsTicketGuard goodsTicketGuard;
    private final GoodsJson goodsJson;
    private final GoodsMapper goodsMapper;
    private final TransactionTemplate transactionTemplate;

    public GoodsCreateResult create(Long memberId, Long ticketId, CreateGoodsCommand command) {
        // 트랜잭션 밖에서 먼저 본다. 틀린 요청에 DB 를 만질 이유가 없다.
        goodsJson.validatePersonLayers(command.personLayers());

        try {
            return transactionTemplate.execute(status -> createInTransaction(memberId, ticketId, command));
        } catch (DataIntegrityViolationException e) {
            // 동시 요청이 유니크 제약에서 갈렸다. 롤백이 끝났으니 새 트랜잭션에서 다시 판정한다.
            log.info("굿즈 생성 유니크 위반 - 재판정 (memberId={}, ticketId={})", memberId, ticketId);
            return transactionTemplate.execute(status -> resolveAfterViolation(memberId, ticketId, command, e));
        }
    }

    private GoodsCreateResult createInTransaction(Long memberId, Long ticketId, CreateGoodsCommand command) {
        Ticket ticket = goodsTicketGuard.requireUsedTicket(memberId, ticketId);

        Optional<GoodsCreateResult> existing = findExisting(memberId, ticketId, command.clientGoodsId());
        if (existing.isPresent()) {
            // 멱등 재전송이다. 이미 만들어진 굿즈를 돌려주므로 key 를 다시 볼 이유가 없다.
            return existing.get();
        }

        requireLiveImages(command);

        Concert concert = ticket.getReservation().getConcert();
        Goods goods = Goods.builder()
                .ticket(ticket)
                .member(memberRepository.getReferenceById(memberId))
                .concert(concert)
                .clientGoodsId(command.clientGoodsId())
                .backgroundKey(command.backgroundKey())
                .sourceBackgroundKey(command.sourceBackgroundKey())
                .personCompositeKey(command.personCompositeKey())
                .depthMapKey(command.depthMapKey())
                .previewKey(command.previewKey())
                .effectType(command.effectType())
                .backgroundFraming(goodsJson.write(command.backgroundFraming()))
                .personLayers(goodsJson.write(command.personLayers()))
                .transitionConfig(goodsJson.write(command.transitionConfig()))
                .renderMetadata(goodsJson.write(command.renderMetadata()))
                .concertSnapshot(goodsJson.concertSnapshot(concert))
                .build();

        // 유니크 위반을 여기서 받으려면 flush 까지 해야 한다. 커밋 시점에 터지면 잡을 곳이 없다.
        Goods saved = goodsRepository.saveAndFlush(goods);
        return new GoodsCreateResult(goodsMapper.toDetail(saved), true);
    }

    /**
     * 컬럼 5개의 key 가 청소 배치에 지워진 것은 아닌지 본다. 하나라도 지워졌으면 409 다.
     *
     * <p>지워진 key 를 그대로 저장하면 DB 에는 key 가 있는데 객체가 없는 <b>깨진 굿즈</b>가 된다.
     * 대장이 지운 행을 남기는 것이 이 판정을 가능하게 한다 — 행까지 지우면 "처음부터 없던 key" 와
     * 구분할 수 없다.
     *
     * <p>{@code personLayers} 안의 key 는 보지 않는다. 그 JSON 구조는 서버가 해석하지 않는다.
     */
    private void requireLiveImages(CreateGoodsCommand command) {
        List<String> imageKeys = new ArrayList<>();
        addIfPresent(imageKeys, command.backgroundKey());
        addIfPresent(imageKeys, command.sourceBackgroundKey());
        addIfPresent(imageKeys, command.personCompositeKey());
        addIfPresent(imageKeys, command.depthMapKey());
        addIfPresent(imageKeys, command.previewKey());

        if (imageKeys.isEmpty()) {
            return;
        }

        if (goodsUploadRepository.countByStatus(imageKeys, GoodsUploadStatus.DELETED) > 0) {
            log.info("굿즈 생성 거절 - 이미 지워진 이미지 key (keys={})", imageKeys);
            throw new GoodsImageDeletedException();
        }
    }

    private void addIfPresent(List<String> imageKeys, String imageKey) {
        if (imageKey != null && !imageKey.isBlank()) {
            imageKeys.add(imageKey);
        }
    }

    /**
     * 유니크 위반 뒤의 재판정. 위반이 설명되면 규칙대로 답하고, 설명되지 않으면 원래 예외를 다시 던진다.
     * 소유·상태는 다시 보지 않는다 — 방금 같은 요청이 통과한 조건이고, 진 쪽도 같은 규칙으로 답해야 한다.
     */
    private GoodsCreateResult resolveAfterViolation(Long memberId,
                                                    Long ticketId,
                                                    CreateGoodsCommand command,
                                                    DataIntegrityViolationException cause) {
        return findExisting(memberId, ticketId, command.clientGoodsId())
                .orElseThrow(() -> cause);
    }

    /**
     * 이미 만든 굿즈가 있으면 그 판정. 비어 있으면 만들어도 된다.
     *
     * <ul>
     *   <li>이 티켓의 <b>내</b> 굿즈가 있고 멱등 키가 같다 → 저장하지 않고 그것을 돌려준다(재시도).</li>
     *   <li>이 티켓의 굿즈가 있는데 남의 것이거나 멱등 키가 다르다 → 409.</li>
     *   <li>이 티켓의 굿즈는 없는데 같은 멱등 키를 <b>다른 티켓</b>에 이미 썼다 → 409. 앱의 키 생성이
     *       잘못된 것이라 {@code uk_goods_member_client} 에서 어차피 막힌다. 먼저 걸러 500 을 피한다.</li>
     * </ul>
     *
     * <p>티켓으로 찾은 굿즈가 <b>내 것인지</b>까지 본다. 멱등 재시도는 같은 사람의 같은 요청일 때만
     * 성립하는데, 소유자를 안 보면 남이 만든 굿즈가 멱등 키만 같아도 200 으로 나가고 그 안에 담긴
     * 저장소 key 와 URL 이 전부 딸려 간다. 지금은 {@code ListingService}·{@code PurchaseService} 가
     * {@code OWNED} 티켓만 거래하게 막아 굿즈를 만든 뒤(=USED) 양도되는 경우가 없지만, 그 규칙은
     * 양도 도메인 것이다. 굿즈 조회가 남의 도메인 상태 규칙에 기대고 있을 이유는 없다.
     */
    private Optional<GoodsCreateResult> findExisting(Long memberId, Long ticketId, String clientGoodsId) {
        Optional<Goods> byTicket = goodsRepository.findByTicketId(ticketId);
        if (byTicket.isPresent()) {
            Goods goods = byTicket.get();
            boolean mine = goods.getMember().getId().equals(memberId);
            if (mine && goods.getClientGoodsId().equals(clientGoodsId)) {
                return Optional.of(new GoodsCreateResult(goodsMapper.toDetail(goods), false));
            }
            // 남의 굿즈든 키가 다르든 답은 같다. uk_goods_ticket 이 1티켓 1굿즈를 못 박고 있어
            // 어느 쪽이든 새로 만들 수는 없다.
            throw new GoodsAlreadyExistsException(ticketId);
        }

        if (goodsRepository.findByMemberIdAndClientGoodsId(memberId, clientGoodsId).isPresent()) {
            log.warn("clientGoodsId 재사용 - 다른 티켓의 굿즈에 이미 쓰인 키 (memberId={}, ticketId={})",
                    memberId, ticketId);
            throw new GoodsAlreadyExistsException(ticketId);
        }

        return Optional.empty();
    }
}
