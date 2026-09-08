package com.ssafy.timo.global.security;

import com.ssafy.timo.global.security.exception.TokenInvalidException;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * 운영에서 쓰는 {@link CurrentMemberProvider}. 아직 인증이 붙지 않아 항상 거절한다.
 *
 * <p>운영에 빈을 아예 두지 않으면 애플리케이션이 뜨지 않아 배포가 깨진다. 반대로
 * {@link MockCurrentMemberProvider} 를 올리면 헤더만 바꿔 남의 계정으로 행세할 수 있다.
 * 그래서 기동은 되게 하되 요청자를 특정해야 하는 기능은 401 로 막는다.
 *
 * <p><b>TODO</b>: JWT 인증이 붙으면 이 클래스는 삭제한다.
 */
@Component
@Profile("prod")
public class DeniedCurrentMemberProvider implements CurrentMemberProvider {

    @Override
    public Long currentMemberId() {
        throw new TokenInvalidException();
    }
}
