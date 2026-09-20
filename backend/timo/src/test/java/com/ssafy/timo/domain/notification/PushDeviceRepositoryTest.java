package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.dto.PushTokenRow;
import com.ssafy.timo.domain.notification.entity.PushDevice;
import com.ssafy.timo.domain.notification.entity.PushPlatform;
import com.ssafy.timo.domain.notification.repository.PushDeviceRepository;
import com.ssafy.timo.domain.notification.service.PushDeviceCleaner;
import com.ssafy.timo.global.config.notification.PushProperties;
import java.lang.reflect.Method;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** 단체 발송이 쓰는 토큰 조회·삭제 쿼리와 설정 바인딩을 실제 MySQL 과 컨텍스트로 확인한다. */
@com.ssafy.timo.support.IntegrationTest
class PushDeviceRepositoryTest {

    @Autowired
    private PushDeviceRepository pushDeviceRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private PushProperties pushProperties;

    @Test
    @DisplayName("여러 회원의 토큰을 회원 id 와 함께 읽고, 묻지 않은 회원의 토큰은 나오지 않는다")
    void findTokenRowsByMemberIdIn_returnsRequestedMembersOnly() {
        Member a = member();
        Member b = member();
        Member other = member();
        device(a, "token-a1");
        device(a, "token-a2");
        device(b, "token-b1");
        device(other, "token-other");

        List<PushTokenRow> rows = pushDeviceRepository.findTokenRowsByMemberIdIn(List.of(a.getId(), b.getId()));

        assertThat(rows).extracting(PushTokenRow::getMemberId, PushTokenRow::getToken)
                .containsExactlyInAnyOrder(
                        org.assertj.core.groups.Tuple.tuple(a.getId(), "token-a1"),
                        org.assertj.core.groups.Tuple.tuple(a.getId(), "token-a2"),
                        org.assertj.core.groups.Tuple.tuple(b.getId(), "token-b1"));
    }

    @Test
    @DisplayName("지정한 토큰만 지우고 지운 개수를 돌려주며, 없는 토큰이 섞여 있어도 예외가 아니다")
    void deleteAllByTokenIn_deletesOnlyGivenTokens() {
        Member member = member();
        device(member, "keep");
        device(member, "drop-1");
        device(member, "drop-2");

        int deleted = pushDeviceRepository.deleteAllByTokenIn(List.of("drop-1", "drop-2", "never-existed"));

        assertThat(deleted).isEqualTo(2);
        assertThat(pushDeviceRepository.findAllByMember_Id(member.getId()))
                .extracting(PushDevice::getToken).containsExactly("keep");
    }

    @Test
    @DisplayName("토큰 삭제는 항상 새 트랜잭션에서 한다 — 커밋 이후에 불리기 때문이다")
    void cleaner_runsInNewTransaction() throws NoSuchMethodException {
        Method method = PushDeviceCleaner.class.getMethod("deleteByTokens", java.util.Collection.class);

        Transactional transactional = method.getAnnotation(Transactional.class);

        assertThat(transactional).isNotNull();
        assertThat(transactional.propagation()).isEqualTo(Propagation.REQUIRES_NEW);
    }

    @Test
    @DisplayName("설정이 없어도 재시도는 2회이고 채널은 비어 있다")
    void pushProperties_haveSafeDefaults() {
        assertThat(pushProperties.retry()).isEqualTo(2);
        assertThat(pushProperties.channel().entry()).isNullOrEmpty();
        assertThat(pushProperties.channel().general()).isNullOrEmpty();
    }

    private void device(Member member, String token) {
        pushDeviceRepository.save(PushDevice.builder()
                .member(member).token(token).platform(PushPlatform.android).build());
    }

    private Member member() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        return memberRepository.save(Member.builder()
                .phoneNumber("010" + suffix.replaceAll("[a-z]", "1"))
                .name("정희성")
                .nickname("티모" + suffix)
                .build());
    }
}
