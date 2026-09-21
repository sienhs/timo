package com.ssafy.timo.domain.goods.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.ssafy.timo.domain.goods.dto.GoodsImageResponseDto;
import com.ssafy.timo.domain.goods.entity.GoodsUpload;
import com.ssafy.timo.domain.goods.exception.GoodsTicketNotOwnedException;
import com.ssafy.timo.domain.goods.exception.GoodsTicketNotUsedException;
import com.ssafy.timo.domain.goods.repository.GoodsRepository;
import com.ssafy.timo.domain.goods.repository.GoodsUploadRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

/**
 * 업로드가 지키는 두 순서를 본다 — 티켓을 먼저 가리고 저장소에 쓰는 것, 그리고 한 장마다 대장을
 * 먼저 적고 올리는 것. 둘 다 어기면 아무도 찾지 못하는 고아가 생긴다.
 */
@ExtendWith(MockitoExtension.class)
class GoodsUploadServiceTest {

    private static final long MEMBER_ID = 7L;
    private static final long TICKET_ID = 42L;
    private static final String KEY_PREFIX = "goods/7/42";

    @Mock
    private GoodsUploadRepository goodsUploadRepository;

    @Mock
    private GoodsRepository goodsRepository;

    @Mock
    private TicketRepository ticketRepository;

    @Mock
    private ImageStorage imageStorage;

    @Mock
    private Ticket ticket;

    private GoodsUploadService service;

    @BeforeEach
    void setUp() {
        service = new GoodsUploadService(goodsUploadRepository,
                new GoodsTicketGuard(ticketRepository), imageStorage);
    }

    @Test
    @DisplayName("입장 완료한 내 티켓이면 대장을 먼저 적고 그 다음에 올린다")
    void recordsBeforeUpload() {
        givenUsedTicket();
        MultipartFile file = image("a.png");
        given(imageStorage.newKey(KEY_PREFIX, file)).willReturn(KEY_PREFIX + "/uuid.png");
        given(imageStorage.getUrl(KEY_PREFIX + "/uuid.png")).willReturn("https://cdn/" + KEY_PREFIX + "/uuid.png");

        List<GoodsImageResponseDto> uploaded = service.upload(MEMBER_ID, TICKET_ID, List.of(file));

        assertThat(uploaded).singleElement()
                .satisfies(image -> {
                    assertThat(image.key()).isEqualTo(KEY_PREFIX + "/uuid.png");
                    assertThat(image.url()).isEqualTo("https://cdn/" + KEY_PREFIX + "/uuid.png");
                });

        InOrder order = inOrder(goodsUploadRepository, imageStorage);
        order.verify(goodsUploadRepository).save(any(GoodsUpload.class));
        order.verify(imageStorage).uploadTo(KEY_PREFIX + "/uuid.png", file);
    }

    @Test
    @DisplayName("key 접두에 회원과 티켓이 들어간다 - 청소가 티켓 단위로 묶을 수 있는 근거다")
    void keyPrefixCarriesMemberAndTicket() {
        givenUsedTicket();
        MultipartFile file = image("a.png");
        given(imageStorage.newKey(KEY_PREFIX, file)).willReturn(KEY_PREFIX + "/uuid.png");

        service.upload(MEMBER_ID, TICKET_ID, List.of(file));

        ArgumentCaptor<GoodsUpload> captor = ArgumentCaptor.forClass(GoodsUpload.class);
        verify(goodsUploadRepository).save(captor.capture());
        assertThat(captor.getValue().getMemberId()).isEqualTo(MEMBER_ID);
        assertThat(captor.getValue().getTicketId()).isEqualTo(TICKET_ID);
        assertThat(captor.getValue().getImageKey()).startsWith(KEY_PREFIX + "/");
    }

    @Test
    @DisplayName("남의 티켓이면 404 이고 저장소도 대장도 건드리지 않는다")
    void rejectsOthersTicketBeforeTouchingStorage() {
        given(ticketRepository.findByIdAndOwnerMemberId(TICKET_ID, MEMBER_ID))
                .willReturn(Optional.empty());

        assertThatThrownBy(() -> service.upload(MEMBER_ID, TICKET_ID, List.of(image("a.png"))))
                .isInstanceOf(GoodsTicketNotOwnedException.class);

        verifyNoInteractions(imageStorage);
        verifyNoInteractions(goodsUploadRepository);
    }

    @Test
    @DisplayName("입장 전 티켓이면 409 이고 저장소도 대장도 건드리지 않는다")
    void rejectsNotUsedTicketBeforeTouchingStorage() {
        given(ticketRepository.findByIdAndOwnerMemberId(TICKET_ID, MEMBER_ID))
                .willReturn(Optional.of(ticket));
        given(ticket.getStatus()).willReturn(TicketStatus.OWNED);

        assertThatThrownBy(() -> service.upload(MEMBER_ID, TICKET_ID, List.of(image("a.png"))))
                .isInstanceOf(GoodsTicketNotUsedException.class);

        verifyNoInteractions(imageStorage);
        verifyNoInteractions(goodsUploadRepository);
    }

    @Test
    @DisplayName("빈 파트는 건너뛴다 - 대장에 빈 줄을 남기지 않는다")
    void skipsEmptyParts() {
        givenUsedTicket();

        List<GoodsImageResponseDto> uploaded = service.upload(MEMBER_ID, TICKET_ID,
                List.of(new MockMultipartFile("files", "empty.png", "image/png", new byte[0])));

        assertThat(uploaded).isEmpty();
        verify(goodsUploadRepository, never()).save(any(GoodsUpload.class));
        verifyNoInteractions(imageStorage);
    }

    private void givenUsedTicket() {
        given(ticketRepository.findByIdAndOwnerMemberId(TICKET_ID, MEMBER_ID))
                .willReturn(Optional.of(ticket));
        given(ticket.getStatus()).willReturn(TicketStatus.USED);
    }

    private MultipartFile image(String name) {
        return new MockMultipartFile("files", name, "image/png", new byte[]{1, 2, 3});
    }
}
