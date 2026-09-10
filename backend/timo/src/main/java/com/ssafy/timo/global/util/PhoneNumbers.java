package com.ssafy.timo.global.util;

public final class PhoneNumbers {

    private static final String NON_DIGIT = "[^0-9]";
    private static final String KR_COUNTRY_CODE = "82";
    private static final String KR_TRUNK_PREFIX = "0";

    private static final int KR_MOBILE_LENGTH = 11;
    private static final int PREFIX_LENGTH = 3;
    private static final int MASKED_LENGTH = 4;
    private static final String MASK = "*";

    private PhoneNumbers() {
    }

    /**
     * 가운데 네 자리를 가린다. {@code 01012345678} 이면 {@code 010****5678} 이다.
     *
     * <p>본인에게 보여주는 값이라도 원본을 그대로 내리지 않는다. 화면 캡처나 화면 공유로
     * 새는 범위를 줄이려는 것이다. 앞뒤를 남기는 이유는 "어느 번호로 가입했는지" 를
     * 확인시켜 주는 것이 이 값의 용도이기 때문이다.
     *
     * <p>정규화된(숫자만) 번호를 넣어야 한다. 길이가 예상과 다르면 통째로 가린다.
     */
    public static String mask(String normalizedPhoneNumber) {
        if (normalizedPhoneNumber == null) {
            return null;
        }
        if (normalizedPhoneNumber.length() != KR_MOBILE_LENGTH) {
            return MASK.repeat(normalizedPhoneNumber.length());
        }
        return normalizedPhoneNumber.substring(0, PREFIX_LENGTH)
                + MASK.repeat(MASKED_LENGTH)
                + normalizedPhoneNumber.substring(PREFIX_LENGTH + MASKED_LENGTH);
    }

    public static String normalize(String rawPhoneNumber) {
        String digits = rawPhoneNumber.replaceAll(NON_DIGIT, "");
        if (digits.startsWith(KR_COUNTRY_CODE)) {
            return KR_TRUNK_PREFIX + digits.substring(KR_COUNTRY_CODE.length());
        }
        return digits;
    }
}
