package com.ssafy.timo.domain.member.service;

import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.member.dto.MemberMeResponseDto;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.global.security.CurrentMemberProvider;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
import com.ssafy.timo.global.util.PhoneNumbers;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원 본인 정보.
 *
 * <p><b>조회 대상을 인자로 받지 않는다.</b> 요청자는 {@link CurrentMemberProvider} 가 access
 * token 에서 꺼내 주고, 그 값으로만 조회한다. 회원 식별자를 파라미터로 받으면 호출하는 쪽에서
 * 남의 식별자를 넘길 수 있고, 그것을 막는 검사를 한 곳이라도 빠뜨리면 남의 정보가 나간다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MemberService {

    private final CurrentMemberProvider currentMemberProvider;
    private final LoginInfoRepository loginInfoRepository;

    /**
     * 요청자 본인의 정보를 돌려준다.
     *
     * <p>토큰이 가리키는 회원이 없으면 401 이다. 404 가 아닌 이유가 있다. 우리가 발급한 토큰의
     * {@code sub} 는 반드시 존재하는 회원이므로, 없다는 것은 <b>그 토큰을 더 이상 신뢰할 수 없다</b>
     * 는 뜻이다. 앱은 404 를 받으면 재시도하지만 401 을 받으면 로그인 화면으로 간다.
     *
     * <p>탈퇴·정지 계정은 403 이다. 탈퇴는 행을 지우지 않고 상태만 바꾸므로 조회 자체는
     * 성공하는데, 남아 있던 access token 으로 정보를 계속 볼 수 있으면 안 된다.
     */
    @Transactional(readOnly = true)
    public MemberMeResponseDto getMyInfo() {
        Long memberId = currentMemberProvider.currentMemberId();

        LoginInfo loginInfo = loginInfoRepository.findByMemberIdWithMember(memberId)
                .orElseThrow(() -> {
                    log.warn("Member not found for a valid token: memberId={}", memberId);
                    return new TokenInvalidException();
                });

        Member member = loginInfo.getMember();
        member.verifyActive();

        return new MemberMeResponseDto(
                member.getId(),
                loginInfo.getUsername(),
                member.getName(),
                member.getNickname(),
                PhoneNumbers.mask(member.getPhoneNumber()));
    }
}
