package com.ssafy.timo.domain.auth.dto;

/**
 * 인증·가입 입력값의 형식 규칙.
 *
 * <p>프론트의 {@code signup_validators.dart} 와 <b>같은 규칙을 유지해야 한다.</b> 서버가 더 좁으면
 * 앱에서 통과한 값이 가입 직전에 400 으로 튕기고, 서버가 더 넓으면 앱을 거치지 않은 요청으로
 * 규칙 밖의 데이터가 들어온다. 한 곳에 모아 둔 이유가 그것이다.
 *
 * <p>길이 상한은 앱의 상수({@code AuthMetrics})를 따른다. DB 컬럼은 그보다 여유가 있다.
 * 예를 들어 아이디는 컬럼이 50자지만 앱이 20자로 막으므로 여기서도 20자다.
 */
public final class AuthPatterns {

    /** 하이픈 없는 숫자 11자리. 앱이 화면에서만 하이픈을 붙이고 보낼 때는 숫자만 보낸다. */
    public static final String PHONE_NUMBER = "^010\\d{8}$";

    public static final String VERIFICATION_CODE = "^\\d{6}$";

    /** 한글 완성형 또는 영문. 단어 사이 공백 한 칸만 허용(영문 이름). */
    public static final String NAME = "^[가-힣a-zA-Z]+( [가-힣a-zA-Z]+)*$";

    /** 첫 글자는 영문 소문자, 이후 영문 소문자·숫자·밑줄. 4~20자. */
    public static final String USERNAME = "^[a-z][a-z0-9_]{3,19}$";

    /** 한글·영문·숫자 2~20자, 공백 없이. */
    public static final String NICKNAME = "^[가-힣a-zA-Z0-9]{2,20}$";

    /**
     * 공백 없는 출력 가능 ASCII 8~20자.
     *
     * <p>영문·숫자·특수문자를 각각 하나 이상 포함해야 한다는 조건은 정규식 하나로 표현하면
     * 읽기 어려워져 {@code @AssertTrue} 로 따로 검사한다.
     */
    public static final String PASSWORD_SHAPE = "^[!-~]{8,20}$";

    private AuthPatterns() {
    }
}
