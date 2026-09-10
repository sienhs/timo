package com.ssafy.timo.domain.auth.dto;

import com.ssafy.timo.global.util.Masked;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.util.regex.Matcher;

/**
 * 회원가입 요청.
 *
 * @param verificationTicket SMS 인증을 통과했다는 증표. {@code /auth/sms/verify} 응답으로 받은 값이다.
 *                           이게 없으면 남의 전화번호로 계정을 만들 수 있어 SMS 인증이 장식이 된다
 * @param phoneNumber        하이픈 없는 숫자. 티켓에 묶인 번호와 같아야 한다
 */
public record SignupRequestDto(

        @NotBlank(message = "본인인증 정보가 필요합니다.")
        String verificationTicket,

        @NotBlank(message = "휴대폰 번호는 필수입니다.")
        @Pattern(regexp = AuthPatterns.PHONE_NUMBER, message = "휴대폰 번호 형식이 올바르지 않습니다.")
        String phoneNumber,

        @NotBlank(message = "이름은 필수입니다.")
        @Pattern(regexp = AuthPatterns.NAME, message = "이름은 한글 또는 영문으로 입력해 주세요.")
        String name,

        @NotBlank(message = "아이디는 필수입니다.")
        @Pattern(regexp = AuthPatterns.USERNAME,
                message = "아이디는 영문 소문자로 시작하는 영문·숫자·밑줄 4~20자입니다.")
        String username,

        @NotBlank(message = "비밀번호는 필수입니다.")
        @Pattern(regexp = AuthPatterns.PASSWORD_SHAPE,
                message = "비밀번호는 공백 없이 8~20자입니다.")
        String password,

        @NotBlank(message = "닉네임은 필수입니다.")
        @Pattern(regexp = AuthPatterns.NICKNAME,
                message = "닉네임은 한글·영문·숫자 2~20자입니다.")
        String nickname
) {

    private static final java.util.regex.Pattern LETTER = java.util.regex.Pattern.compile("[A-Za-z]");
    private static final java.util.regex.Pattern DIGIT = java.util.regex.Pattern.compile("\\d");
    private static final java.util.regex.Pattern SPECIAL =
            java.util.regex.Pattern.compile("[!-/:-@\\[-`{-~]");

    /**
     * 비밀번호가 영문·숫자·특수문자를 모두 포함하는지.
     *
     * <p>길이·문자 종류와 분리한 이유는 응답 때문이다. 하나의 정규식으로 합치면 어느 조건이
     * 모자란지 알려줄 수 없어 "형식이 올바르지 않습니다" 만 나간다.
     */
    @AssertTrue(message = "비밀번호에 영문·숫자·특수문자를 모두 포함해 주세요.")
    public boolean isPasswordComposedOfAllCharacterTypes() {
        if (password == null) {
            return true;   // @NotBlank 가 따로 알려준다.
        }
        return find(LETTER) && find(DIGIT) && find(SPECIAL);
    }

    private boolean find(java.util.regex.Pattern pattern) {
        Matcher matcher = pattern.matcher(password);
        return matcher.find();
    }

    @Override
    public String toString() {
        return "SignupRequestDto[verificationTicket=%s, phoneNumber=%s, name=%s, username=%s, password=%s, nickname=%s]"
                .formatted(Masked.of(verificationTicket), Masked.of(phoneNumber), Masked.of(name),
                        username, Masked.of(password), nickname);
    }
}
