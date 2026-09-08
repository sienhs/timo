package com.ssafy.timo.domain.auth.service;

import com.ssafy.timo.domain.auth.dto.SignupRequestDto;
import com.ssafy.timo.domain.auth.dto.SignupResponseDto;
import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.exception.NicknameDuplicatedException;
import com.ssafy.timo.domain.auth.exception.PhoneNumberDuplicatedException;
import com.ssafy.timo.domain.auth.exception.UsernameDuplicatedException;
import com.ssafy.timo.domain.auth.exception.VerificationTicketInvalidException;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.auth.repository.SmsVerificationStore;
import com.ssafy.timo.domain.auth.service.AccessTokenProvider.AccessToken;
import com.ssafy.timo.domain.auth.service.RefreshTokenProvider.IssuedRefreshToken;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.global.util.PhoneNumbers;
import com.ssafy.timo.global.util.Sha256;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원가입.
 *
 * <p>SMS 인증과 가입을 분리해 둔 이유가 있다. 인증 단계에서 발급한 <b>검증 티켓</b>을 가입 요청이
 * 다시 제출해야 통과한다. 티켓 없이 전화번호만 믿으면 아무 번호로나 계정을 만들 수 있어
 * SMS 인증이 아무것도 막지 못하게 된다.
 *
 * <p>중복은 두 번 본다. 먼저 조회로 걸러 친절한 메시지를 주고, 그 사이 남이 같은 값을 채간 경우는
 * DB 유니크 제약이 최종 판정한다. 조회만으로는 확인과 저장 사이의 틈을 막을 수 없고,
 * 제약만으로는 어느 값이 문제인지 사용자에게 알려주기 어렵다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SignupService {

    private final SmsVerificationStore smsVerificationStore;
    private final MemberRepository memberRepository;
    private final LoginInfoRepository loginInfoRepository;
    private final PasswordEncoder passwordEncoder;
    private final AccessTokenProvider accessTokenProvider;
    private final RefreshTokenProvider refreshTokenProvider;

    @Transactional
    public SignupResponseDto signUp(SignupRequestDto request, String deviceId) {
        String phoneNumber = PhoneNumbers.normalize(request.phoneNumber());
        String ticketHash = Sha256.hex(request.verificationTicket());

        verifyTicket(ticketHash, phoneNumber);
        checkDuplicates(phoneNumber, request);

        Member member = save(request, phoneNumber);

        // 가입이 확정된 뒤에 소비한다. 앞에서 지우면 저장이 실패했을 때 다시 인증받아야 한다.
        smsVerificationStore.deleteTicket(ticketHash);

        AccessToken accessToken = accessTokenProvider.issue(member.getId(), member.getRole());
        IssuedRefreshToken refreshToken = refreshTokenProvider.issue(member, deviceId);

        log.info("Member signed up: memberId={}, deviceId={}", member.getId(), deviceId);

        return new SignupResponseDto(
                member.getId(), accessToken.value(), refreshToken.value(), accessToken.expiresInSeconds());
    }

    /**
     * 티켓이 살아 있고, 그 티켓이 <b>이 번호의</b> 인증으로 발급된 것인지 본다.
     *
     * <p>번호 일치를 안 보면 자기 번호로 받은 티켓에 남의 번호를 실어 가입할 수 있다.
     */
    private void verifyTicket(String ticketHash, String phoneNumber) {
        String verifiedPhoneNumber = smsVerificationStore.findPhoneNumberByTicket(ticketHash)
                .orElseThrow(VerificationTicketInvalidException::new);

        if (!verifiedPhoneNumber.equals(phoneNumber)) {
            log.warn("Verification ticket does not match the requested phone number");
            throw new VerificationTicketInvalidException();
        }
    }

    private void checkDuplicates(String phoneNumber, SignupRequestDto request) {
        if (memberRepository.existsByPhoneNumber(phoneNumber)) {
            throw new PhoneNumberDuplicatedException();
        }
        if (memberRepository.existsByNickname(request.nickname())) {
            throw new NicknameDuplicatedException();
        }
        if (loginInfoRepository.existsByUsername(request.username())) {
            throw new UsernameDuplicatedException();
        }
    }

    /**
     * 회원과 로그인 수단을 함께 저장한다.
     *
     * <p>{@code saveAndFlush} 를 쓰는 이유는 {@link LoginInfo} 의 식별자가 {@code @MapsId} 로 이미
     * 정해져 있어 INSERT 가 트랜잭션 커밋까지 미뤄지기 때문이다. 그대로 두면 유니크 제약 위반이
     * 이 메서드 밖에서 터져 아이디 중복을 409 로 바꿀 기회를 놓친다.
     * ({@link Member} 는 IDENTITY 라 {@code save()} 시점에 곧바로 INSERT 된다.)
     */
    private Member save(SignupRequestDto request, String phoneNumber) {
        try {
            Member member = memberRepository.save(Member.builder()
                    .phoneNumber(phoneNumber)
                    .name(request.name())
                    .nickname(request.nickname())
                    .build());

            loginInfoRepository.saveAndFlush(LoginInfo.builder()
                    .member(member)
                    .username(request.username())
                    .passwordHash(passwordEncoder.encode(request.password()))
                    .build());

            return member;
        } catch (RuntimeException e) {
            throw toDuplicateException(e);
        }
    }

    /**
     * 유니크 제약 위반을 어느 값이 겹쳤는지에 맞는 예외로 바꾼다.
     *
     * <p>여기까지 오는 건 중복 확인을 통과한 뒤 저장 직전에 남이 같은 값을 채간 경우뿐이다.
     * 드물지만 그때 500 을 주면 사용자는 무엇이 문제인지 알 수 없다.
     *
     * <p>MySQL 이 돌려주는 제약 이름에는 {@code member.uk_member_nickname} 처럼 테이블명이 앞에 붙는다.
     */
    private RuntimeException toDuplicateException(RuntimeException e) {
        for (Throwable cause = e; cause != null; cause = cause.getCause()) {
            if (!(cause instanceof ConstraintViolationException violation)) {
                continue;
            }

            String constraintName = violation.getConstraintName();
            if (constraintName == null) {
                break;
            }

            log.warn("Signup lost a race on a unique constraint: {}", constraintName);
            return switch (constraintName.substring(constraintName.lastIndexOf('.') + 1)) {
                case "uk_member_nickname" -> new NicknameDuplicatedException();
                case "uk_member_phone_number" -> new PhoneNumberDuplicatedException();
                case "uk_login_info_username" -> new UsernameDuplicatedException();
                default -> e;
            };
        }
        return e;
    }
}
