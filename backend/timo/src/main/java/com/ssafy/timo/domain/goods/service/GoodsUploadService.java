package com.ssafy.timo.domain.goods.service;

import com.ssafy.timo.domain.goods.dto.GoodsImageResponseDto;
import com.ssafy.timo.domain.goods.entity.GoodsUpload;
import com.ssafy.timo.domain.goods.repository.GoodsUploadRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/**
 * 굿즈 이미지 업로드. 앱이 온디바이스로 만든 이미지를 받아 저장소에 넣고 key 를 돌려준다.
 *
 * <p><b>티켓을 먼저 가리고 그 다음에 올린다.</b> 거절될 요청이 저장소에 객체를 하나도 만들지 않게
 * 하려는 것이다. 올려 놓고 나중에 가리면 거절 한 번마다 고아가 쌓이고, 그 고아는 청소 배치가
 * 떠안는다. 판정은 굿즈 생성과 같은 규칙이고({@link GoodsTicketGuard}) 거절 코드도 같다.
 *
 * <p>덤으로 업로드 남용 한도가 따로 필요 없다. 입장을 마친 자기 티켓을 가진 사람만 올릴 수 있다.
 * 다만 이 순서가 막는 것은 <b>S3 객체와 그 비용</b>이지 네트워크 전송이 아니다 - multipart 라
 * 바이트는 스프링이 파트를 파싱하는 동안 이미 서버까지 와 있다.
 *
 * <p><b>한 장마다 대장을 먼저 적고 저장소에 쓴다.</b> 사이에서 끊기면 올라가지 않은 key 의 행이
 * 남는데, 청소 배치가 지우려 할 때 {@code ImageStorage.delete} 는 없는 key 에도 예외를 던지지
 * 않으므로 조용히 정리된다. 반대 순서였다면 대장에 없는 key 가 생겨 어느 배치도 찾지 못하는
 * 고아가 된다.
 *
 * <p><b>트랜잭션을 통째로 열지 않는다.</b> 열어 두면 세 번째 장에서 실패했을 때 앞의 두 행이
 * 함께 롤백되는데, 그 둘은 저장소에 이미 올라가 있어 대장 없는 고아가 된다. 행마다 따로 커밋해야
 * 위 순서가 실제로 지켜진다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GoodsUploadService {

    private final GoodsUploadRepository goodsUploadRepository;
    private final GoodsTicketGuard goodsTicketGuard;
    private final ImageStorage imageStorage;

    public List<GoodsImageResponseDto> upload(Long memberId, Long ticketId, List<MultipartFile> files) {
        goodsTicketGuard.requireUsedTicket(memberId, ticketId);

        String keyPrefix = keyPrefix(memberId, ticketId);
        List<GoodsImageResponseDto> uploaded = new ArrayList<>();
        for (MultipartFile file : files) {
            if (file == null || file.isEmpty()) {
                continue;
            }
            uploaded.add(uploadOne(memberId, ticketId, keyPrefix, file));
        }

        log.info("굿즈 이미지 업로드 (memberId={}, ticketId={}, count={})", memberId, ticketId, uploaded.size());
        return uploaded;
    }

    /**
     * key 접두. 굿즈가 티켓에 붙으므로 업로드도 티켓까지 좁혀 묶는다 - 청소가 티켓 단위로 판정할 수
     * 있는 것도, "이 key 가 이 굿즈 것인가" 를 접두만으로 따질 수 있는 것도 이 모양 덕이다.
     */
    private String keyPrefix(Long memberId, Long ticketId) {
        return "goods/" + memberId + "/" + ticketId;
    }

    private GoodsImageResponseDto uploadOne(Long memberId, Long ticketId, String keyPrefix, MultipartFile file) {
        // 형식 검증이 여기서 끝난다. 허용 밖이면 key 가 나오지 않으므로 대장에도 남지 않는다.
        String imageKey = imageStorage.newKey(keyPrefix, file);

        goodsUploadRepository.save(GoodsUpload.of(memberId, ticketId, imageKey));
        imageStorage.uploadTo(imageKey, file);

        return new GoodsImageResponseDto(imageKey, imageStorage.getUrl(imageKey));
    }
}
