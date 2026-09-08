package com.ssafy.timo.domain.auth.service;

import com.ssafy.timo.domain.auth.dto.AvailabilityRequestDto;
import com.ssafy.timo.domain.auth.dto.AvailabilityResponseDto;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 아이디·닉네임 중복 확인.
 *
 * <p>아이디는 {@code login_info}, 닉네임은 {@code member} 에 있어 리포지토리가 갈린다.
 * 가입 화면에서는 같은 버튼 하나로 보이므로 그 갈림을 여기서 흡수한다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AvailabilityService {

    private final MemberRepository memberRepository;
    private final LoginInfoRepository loginInfoRepository;

    public AvailabilityResponseDto check(AvailabilityRequestDto request) {
        boolean taken = request.isUsernameCheck()
                ? loginInfoRepository.existsByUsername(request.username())
                : memberRepository.existsByNickname(request.nickname());

        return new AvailabilityResponseDto(!taken);
    }
}
