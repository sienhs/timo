package com.ssafy.timo.domain.captcha.service;

import com.ssafy.timo.domain.captcha.client.CaptchaClient;
import com.ssafy.timo.domain.captcha.dto.CaptchaIssueResponseDto;
import com.ssafy.timo.domain.captcha.dto.CaptchaVerifyRequestDto;
import com.ssafy.timo.domain.captcha.dto.CaptchaVerifyResponseDto;
import com.ssafy.timo.domain.captcha.exception.CaptchaKeyNotFoundException;
import com.ssafy.timo.domain.captcha.exception.CaptchaKeyOwnerMismatchException;
import com.ssafy.timo.domain.captcha.exception.CaptchaMismatchException;
import com.ssafy.timo.domain.captcha.exception.CaptchaProviderException;
import com.ssafy.timo.domain.captcha.exception.CaptchaTooManyRequestsException;
import com.ssafy.timo.domain.captcha.repository.CaptchaKeyStore;
import com.ssafy.timo.domain.captcha.repository.CaptchaPassedStore;
import com.ssafy.timo.domain.captcha.repository.CaptchaRateStore;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.global.config.captcha.NaverCaptchaProperties;
import java.util.Base64;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 캡차 발급.
 *
 * <p><b>저장은 마지막이다.</b> 키를 받고 이미지까지 받은 뒤에 저장한다. 순서를 뒤집으면
 * 이미지 조회가 실패했을 때, 사용자가 풀 수 없는 캡차 키가 주인까지 달고 2분 동안 남는다.
 *
 * <p><b>횟수 검사는 공급자를 부르기 전에 한다.</b> 네이버 API 에는 호출 한도가 있어, 막을 요청
 * 때문에 그 한도를 먼저 써 버리면 정상 사용자가 캡차를 못 받는다.
 *
 * <p>거절된 시도도 횟수에 센다. 세지 않으면 한도에 걸린 쪽이 계속 두드려도 카운터가 더는 오르지
 * 않아, 창이 지나는 순간 쌓아 둔 요청이 한꺼번에 나간다.
 *
 * <p>트랜잭션이 없다. 건드리는 것이 캐시뿐이라 걸어 봐야 아무것도 묶이지 않는다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CaptchaService {

    /** 네이버 캡차가 내려주는 형식이다. 응답의 {@code imageType} 으로 그대로 나간다. */
    private static final String IMAGE_TYPE = "image/jpeg";

    private final CaptchaClient captchaClient;
    private final CaptchaKeyStore captchaKeyStore;
    private final CaptchaRateStore captchaRateStore;
    private final CaptchaPassedStore captchaPassedStore;
    private final ConcertRepository concertRepository;
    private final NaverCaptchaProperties properties;

    /**
     * 이 회원 앞으로 캡차를 하나 발급한다.
     *
     * @throws CaptchaTooManyRequestsException 이번 창의 발급 한도를 넘었으면 (429)
     * @throws CaptchaProviderException        공급자 호출이 실패하면 (502). 이때 저장소에는 아무것도 남지 않는다
     */
    public CaptchaIssueResponseDto issue(Long memberId) {
        int attempts = captchaRateStore.increment(memberId);
        if (attempts > properties.issueLimitPerMinute()) {
            log.warn("캡차 발급 한도 초과 (memberId={}, attempts={})", memberId, attempts);
            throw new CaptchaTooManyRequestsException();
        }

        String captchaKey = captchaClient.issueKey();
        byte[] image = captchaClient.fetchImage(captchaKey);

        captchaKeyStore.save(captchaKey, memberId);
        log.debug("캡차 발급 (memberId={})", memberId);

        return new CaptchaIssueResponseDto(
                captchaKey,
                Base64.getEncoder().encodeToString(image),
                IMAGE_TYPE,
                properties.keyTtl().toSeconds());
    }

    /**
     * 캡차 키가 이 회원 몫으로 발급된 게 맞는지, 입력값이 맞는지 확인하고 통과 기록을 남긴다.
     *
     * <p>공연 존재 여부를 키보다 먼저 본다. 없는 공연으로 잘못 보낸 요청 때문에 정상적인 키가
     * 소비되면 안 된다.
     *
     * <p>키는 결과와 무관하게 여기서 폐기된다({@link CaptchaKeyStore#getAndEvict}) - 1회용이라
     * 오답이든 남의 키든 같은 키로 다시 쓸 수 없어야 한다.
     *
     * @throws ConcertNotFoundException         없는 공연이면 (404)
     * @throws CaptchaKeyNotFoundException      키가 없거나 만료·소비됐으면 (404)
     * @throws CaptchaKeyOwnerMismatchException 남에게 발급된 키면 (403)
     * @throws CaptchaMismatchException          입력값이 틀렸으면 (400)
     * @throws CaptchaProviderException         공급자 호출이 실패하면 (502)
     */
    public CaptchaVerifyResponseDto verify(Long memberId, CaptchaVerifyRequestDto request) {
        if (!concertRepository.existsById(request.concertId())) {
            throw new ConcertNotFoundException(request.concertId());
        }

        Long owner = captchaKeyStore.getAndEvict(request.captchaKey())
                .orElseThrow(CaptchaKeyNotFoundException::new);
        if (!owner.equals(memberId)) {
            throw new CaptchaKeyOwnerMismatchException();
        }

        if (!captchaClient.verify(request.captchaKey(), request.value())) {
            throw new CaptchaMismatchException();
        }

        captchaPassedStore.markPassed(request.concertId(), memberId);
        log.debug("캡차 검증 통과 (memberId={}, concertId={})", memberId, request.concertId());

        return new CaptchaVerifyResponseDto(properties.passedTtl().toSeconds());
    }
}
