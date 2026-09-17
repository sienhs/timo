package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.dto.PushDeviceRegistrationRequest;
import com.ssafy.timo.domain.notification.entity.PushDevice;
import com.ssafy.timo.domain.notification.repository.PushDeviceRepository;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/** 앱 설치본과 회원을 연결한다. 발송 트리거를 정하는 도메인 서비스와 분리해 재사용한다. */
@Service
@RequiredArgsConstructor
public class PushDeviceService {

    private final PushDeviceRepository pushDeviceRepository;
    private final MemberRepository memberRepository;

    @Transactional
    public void register(Long memberId, PushDeviceRegistrationRequest request) {
        Member member = memberRepository.getReferenceById(memberId);
        pushDeviceRepository.findByToken(request.token())
                .ifPresentOrElse(
                        device -> device.refresh(member, request.platform()),
                        () -> pushDeviceRepository.save(PushDevice.builder()
                                .member(member)
                                .token(request.token())
                                .platform(request.platform())
                                .build()));
    }

    @Transactional
    public void unregister(Long memberId, String token) {
        // 다른 회원의 토큰을 지울 수 없으며, 이미 사라진 토큰도 성공으로 취급해 앱 로그아웃을 멱등으로 둔다.
        pushDeviceRepository.deleteByTokenAndMember_Id(token, memberId);
    }
}
