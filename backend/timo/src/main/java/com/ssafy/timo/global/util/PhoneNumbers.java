package com.ssafy.timo.global.util;

public final class PhoneNumbers {

    private static final String NON_DIGIT = "[^0-9]";
    private static final String KR_COUNTRY_CODE = "82";
    private static final String KR_TRUNK_PREFIX = "0";

    private PhoneNumbers() {
    }

    public static String normalize(String rawPhoneNumber) {
        String digits = rawPhoneNumber.replaceAll(NON_DIGIT, "");
        if (digits.startsWith(KR_COUNTRY_CODE)) {
            return KR_TRUNK_PREFIX + digits.substring(KR_COUNTRY_CODE.length());
        }
        return digits;
    }
}
