package com.ssafy.timo.domain.concert.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 그 공연의 티켓을 지금 가지고 있지 않은 사람이 소재를 보려 한 경우.
 *
 * <p>공연 자체는 인증 없이 열리는 공개 정보라 존재를 숨길 이유가 없다. 그래서 굿즈 도메인의 404
 * 규칙과 달리 <b>403</b> 이다 - 있는지 없는지가 아니라 볼 자격이 없다는 뜻이다.
 */
public class ConcertKitForbiddenException extends BusinessException {

    public ConcertKitForbiddenException() {
        super(ConcertErrorCode.CONCERT_KIT_FORBIDDEN);
    }
}
