package com.ssafy.timo.domain.wallet;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.wallet.entity.Wallet;
import com.ssafy.timo.domain.wallet.repository.WalletRepository;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.hibernate.exception.ConstraintViolationException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * 지갑의 저장 동작을 실제 MySQL 로 확인한다.
 *
 * <p>{@code member_id} 를 PK 로 공유하는 것과, 주소가 겹칠 때 어느 제약이 깨졌는지 알 수
 * 있는지를 본다 - {@link com.ssafy.timo.domain.member.MemberPersistenceTest} 가 회원·로그인
 * 수단에 대해 확인하는 것과 같은 이유다.
 */
@IntegrationTest
class WalletPersistenceTest {

    private static final String ADDRESS = "0xF90259A926dE751ed07d2e8908868A3d2D2C4a7A";
    private static final String KEYSTORE_JSON = "{\"version\":3}";
    private static final String WRAPPED_DEK = "wrapped-dek-dummy-value";

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private WalletRepository walletRepository;

    @Autowired
    private EntityManager em;

    @Test
    @DisplayName("지갑은 회원 식별자를 PK 로 공유하고, 생성 시각이 남는다")
    void wallet_sharesMemberId() {
        Member member = memberRepository.save(member("01012345678", "티모"));

        Wallet wallet = walletRepository.save(wallet(member, ADDRESS));

        assertThat(wallet.getMemberId()).isEqualTo(member.getId());
        assertThat(wallet.getCreatedAt()).isNotNull();
    }

    @Test
    @DisplayName("저장한 지갑을 회원 식별자로 다시 조회할 수 있다")
    void wallet_isFindableByMemberId() {
        Member member = memberRepository.save(member("01012345678", "티모"));
        walletRepository.save(wallet(member, ADDRESS));

        Wallet found = walletRepository.findById(member.getId()).orElseThrow();

        assertThat(found.getAddress()).isEqualTo(ADDRESS);
        assertThat(found.getEncryptedKeystoreJson()).isEqualTo(KEYSTORE_JSON);
        assertThat(found.getWrappedDek()).isEqualTo(WRAPPED_DEK);
    }

    @Test
    @DisplayName("주소가 겹치면 어느 제약이 깨졌는지 알 수 있다")
    void duplicateAddress_reportsConstraintName() {
        Member first = memberRepository.save(member("01012345678", "티모"));
        Member second = memberRepository.save(member("01099998888", "다른티모"));
        walletRepository.saveAndFlush(wallet(first, ADDRESS));

        assertThat(violatedConstraintOf(() -> walletRepository.saveAndFlush(wallet(second, ADDRESS))))
                .isEqualTo("uk_wallet_address");
    }

    /**
     * 저장을 터뜨리고, 위반된 유니크 제약의 이름을 꺼낸다.
     *
     * <p>{@link Wallet} 은 {@code @MapsId} 로 식별자가 이미 정해져 있어 INSERT 가 flush 까지
     * 밀리므로, {@code save()} 가 아니라 {@code saveAndFlush()} 로 그 시점에 바로 터뜨린다.
     */
    private String violatedConstraintOf(Runnable save) {
        Exception exception = catchThrowableOfType(Exception.class, save::run);
        assertThat(exception).as("중복인데 저장이 통과했다").isNotNull();

        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof ConstraintViolationException violation) {
                String name = violation.getConstraintName();
                return name == null ? null : name.substring(name.lastIndexOf('.') + 1);
            }
        }
        throw new AssertionError("ConstraintViolationException 을 찾지 못했다: " + exception);
    }

    private Member member(String phoneNumber, String nickname) {
        return Member.builder()
                .phoneNumber(phoneNumber)
                .name("정희성")
                .nickname(nickname)
                .build();
    }

    private Wallet wallet(Member member, String address) {
        return Wallet.builder()
                .member(member)
                .address(address)
                .encryptedKeystoreJson(KEYSTORE_JSON)
                .wrappedDek(WRAPPED_DEK)
                .build();
    }
}
