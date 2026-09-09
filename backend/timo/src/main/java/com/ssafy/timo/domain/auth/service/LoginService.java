package com.ssafy.timo.domain.auth.service;

import com.ssafy.timo.domain.auth.dto.LoginRequestDto;
import com.ssafy.timo.domain.auth.dto.LoginResponseDto;
import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.exception.LoginFailedException;
import com.ssafy.timo.domain.auth.exception.MemberSuspendedException;
import com.ssafy.timo.domain.auth.exception.MemberWithdrawnException;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.auth.service.AccessTokenProvider.AccessToken;
import com.ssafy.timo.domain.auth.service.RefreshTokenProvider.IssuedRefreshToken;
import com.ssafy.timo.domain.member.entity.Member;
import java.util.Optional;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 아이디·비밀번호 로그인.
 *
 * <p>하는 일은 {@link SignupService} 의 뒷부분과 같다. 회원이 확정되면 access 와 refresh 를
 * 함께 발급한다. 다른 것은 앞부분뿐이다. 가입은 <b>SMS 검증 티켓</b>으로 본인을 확인하고,
 * 로그인은 <b>비밀번호 대조</b>로 확인한다.
 *
 * <p>이 클래스의 설계 대부분은 <b>어느 쪽이 틀렸는지 알려주지 않는 것</b>에서 나온다.
 * "없는 아이디" 와 "비밀번호 틀림" 을 구분해 주면 가입된 아이디 목록을 밖에서 수집할 수 있다.
 * 프론트도 같은 전제로 만들어져 있다({@code AuthStrings.loginFailed} 문구 하나뿐이다).
 */
@Slf4j
@Service
public class LoginService {

    private final LoginInfoRepository loginInfoRepository;
    private final PasswordEncoder passwordEncoder;
    private final AccessTokenProvider accessTokenProvider;
    private final RefreshTokenProvider refreshTokenProvider;

    /** 아이디가 없을 때 대조 상대로 쓰는 해시. 어떤 비밀번호와도 일치하지 않는다. */
    private final String dummyPasswordHash;

    public LoginService(LoginInfoRepository loginInfoRepository,
                        PasswordEncoder passwordEncoder,
                        AccessTokenProvider accessTokenProvider,
                        RefreshTokenProvider refreshTokenProvider) {

        this.loginInfoRepository = loginInfoRepository;
        this.passwordEncoder = passwordEncoder;
        this.accessTokenProvider = accessTokenProvider;
        this.refreshTokenProvider = refreshTokenProvider;

        // 상수로 박아 두지 않는 이유가 있다. BCrypt 강도 설정이 바뀌면 박아 둔 해시만 옛 강도로
        // 남아 대조 시간이 갈리고, 아래의 타이밍 방어가 조용히 무력해진다. 같은 인코더로 만든다.
        this.dummyPasswordHash = passwordEncoder.encode(UUID.randomUUID().toString());
    }

    /**
     * 아이디·비밀번호를 확인하고 토큰을 발급한다.
     *
     * <p>{@code readOnly = true} 를 붙이면 안 된다. 조회만 하는 것처럼 보이지만
     * {@link RefreshTokenProvider#issue} 가 기존 세션 행을 갱신한다. 읽기 전용 트랜잭션에
     * 참여하면 Hibernate 가 flush 를 하지 않아 <b>재로그인 시 토큰 회전이 조용히 사라진다.</b>
     * 첫 로그인은 INSERT 라 동작하고 재로그인만 깨지므로 눈치채기 어렵다.
     */
    @Transactional
    public LoginResponseDto login(LoginRequestDto request, String deviceId) {
        Optional<LoginInfo> found = loginInfoRepository.findByUsernameWithMember(request.username());

        // 아이디가 없어도 대조를 "수행한다". 건너뛰면 BCrypt 시간만큼 응답이 빨라져,
        // 메시지를 똑같이 맞춰 놓아도 응답 시간 차이만으로 아이디 존재 여부가 드러난다.
        String passwordHash = found.map(LoginInfo::getPasswordHash).orElse(dummyPasswordHash);
        boolean matched = passwordEncoder.matches(request.password(), passwordHash);

        if (found.isEmpty() || !matched) {
            // 사유를 나누지 않는다. 로그에도 아이디를 남기지 않는다.
            log.warn("Login failed: deviceId={}", deviceId);
            throw new LoginFailedException();
        }

        Member member = found.get().getMember();
        checkLoginable(member);

        AccessToken accessToken = accessTokenProvider.issue(member.getId(), member.getRole());
        IssuedRefreshToken refreshToken = refreshTokenProvider.issue(member, deviceId);

        log.info("Member logged in: memberId={}, deviceId={}", member.getId(), deviceId);

        return new LoginResponseDto(
                member.getId(), accessToken.value(), refreshToken.value(), accessToken.expiresInSeconds());
    }

    /**
     * 계정 상태를 본다. 비밀번호를 <b>맞힌 뒤</b>에 검사하므로 이미 본인이 확인된 상태고,
     * 열거 걱정 없이 사유를 그대로 알려줘도 된다. 그래서 {@code LOGIN_FAILED} 와 코드를 나눈다.
     *
     * <p>{@code MemberStatus} 에 상태를 추가하면 여기도 같이 봐야 한다. 빠뜨리면 그 상태의
     * 계정이 <b>그냥 로그인된다.</b>
     */
    private void checkLoginable(Member member) {
        switch (member.getStatus()) {
            case ACTIVE -> { }
            case SUSPENDED -> throw new MemberSuspendedException();
            case WITHDRAWN -> throw new MemberWithdrawnException();
        }
    }
}
