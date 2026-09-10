package com.ssafy.timo.domain.wallet.crypto;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** {@link MasterKey} 의 형식 검증과 원문 노출 방지를 확인한다. */
class MasterKeyTest {

    private static final String VALID_KEY = "0123456789abcdef".repeat(4);

    @Test
    @DisplayName("64자 16진수 문자열이면 정상 생성되고, expose()로 원문을 그대로 돌려받는다")
    void validHexKey_succeeds() {
        assertThat(MasterKey.of(VALID_KEY).expose()).isEqualTo(VALID_KEY);
    }

    @Test
    @DisplayName("대문자 16진수도 허용한다")
    void uppercaseHexKey_isAlsoAccepted() {
        String upperCaseKey = VALID_KEY.toUpperCase();

        assertThat(MasterKey.of(upperCaseKey).expose()).isEqualTo(upperCaseKey);
    }

    @Test
    @DisplayName("설정하지 않으면 기동 시점에 막고, 값이 없다는 것을 알려준다")
    void missingKey_failsFastWithAMissingValueMessage() {
        assertThatThrownBy(() -> MasterKey.of(null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("설정되지 않았습니다");
    }

    @Test
    @DisplayName("공백만 있는 값도 설정하지 않은 것으로 본다")
    void blankKey_failsFastWithAMissingValueMessage() {
        assertThatThrownBy(() -> MasterKey.of("   "))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("설정되지 않았습니다");
    }

    @Test
    @DisplayName("64자보다 짧으면 막고, 형식이 잘못됐다는 것을 알려준다")
    void tooShortKey_failsFastWithAFormatMessage() {
        assertThatThrownBy(() -> MasterKey.of(VALID_KEY.substring(1)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("64자 16진수 문자열");
    }

    @Test
    @DisplayName("16진수가 아닌 문자가 섞이면 형식 오류로 막는다")
    void nonHexCharacters_failFastWithAFormatMessage() {
        String withNonHexChar = "g" + VALID_KEY.substring(1);

        assertThatThrownBy(() -> MasterKey.of(withNonHexChar))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("64자 16진수 문자열");
    }

    @Test
    @DisplayName("toString()은 원문 대신 지문만 보여주고, 매번 같은 값에 대해 같은 지문을 돌려준다")
    void toString_showsFingerprintNotTheRawKey() {
        String fingerprint = MasterKey.of(VALID_KEY).toString();

        assertThat(fingerprint).doesNotContain(VALID_KEY).contains("fp:");
        assertThat(MasterKey.of(VALID_KEY)).hasToString(fingerprint);
    }

    @Test
    @DisplayName("값이 다르면 지문도 다르다")
    void toString_differsForDifferentKeys() {
        String otherKey = "f".repeat(64);

        assertThat(MasterKey.of(VALID_KEY)).doesNotHaveToString(MasterKey.of(otherKey).toString());
    }

    @Test
    @DisplayName("같은 원문이면 같은 값으로 취급한다")
    void equals_isBasedOnTheRawValue() {
        assertThat(MasterKey.of(VALID_KEY)).isEqualTo(MasterKey.of(VALID_KEY));
    }
}
