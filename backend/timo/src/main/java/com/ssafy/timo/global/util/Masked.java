package com.ssafy.timo.global.util;

/**
 * 로그에 값이 남으면 안 되는 문자열을 길이 표기로 바꾼다.
 *
 * <p>record 는 {@code toString()} 을 자동으로 만들어 준다. 그 안에 비밀번호·토큰·인증번호가
 * 들어 있으면 <b>{@code log.debug("{}", request)} 한 줄로 원문이 로그에 남는다.</b> 지금 그렇게
 * 쓰는 코드는 없지만, 한 번 새면 되돌릴 수 없는 값들이라 DTO 쪽에서 미리 막아 둔다.
 *
 * <p>값을 아예 지우지 않고 길이를 남기는 이유가 있다. "값이 오긴 했는지", "빈 문자열로 왔는지" 를
 * 구분할 수 있어야 검증 실패를 추적할 수 있다. 길이만으로는 값을 되돌릴 수 없다.
 */
public final class Masked {

    private Masked() {
    }

    /** {@code null} 과 빈 값을 구분해 남긴다. 그 밖에는 길이만 남긴다. */
    public static String of(String value) {
        if (value == null) {
            return "null";
        }
        return "<%d chars>".formatted(value.length());
    }
}
