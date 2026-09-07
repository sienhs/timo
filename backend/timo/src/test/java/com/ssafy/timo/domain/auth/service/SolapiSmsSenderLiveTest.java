package com.ssafy.timo.domain.auth.service;

import static org.assertj.core.api.Assertions.assertThatCode;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

@EnabledIfEnvironmentVariable(named = "SMS_LIVE_TEST", matches = "true")
class SolapiSmsSenderLiveTest {

    private static final Path ENV_FILE = Path.of(".env");
    private static final String COMMENT_PREFIX = "#";
    private static final char KEY_VALUE_SEPARATOR = '=';

    private static final String TEST_CODE = "132490";

    @Test
    @DisplayName("실제 문자가 발송된다 (SMS_LIVE_TEST=true 일 때만 실행, 요금 발생)")
    void sendVerificationCode() throws IOException {
        Map<String, String> env = loadEnv();

        String apiKey = env.get("SOLAPI_API_KEY");
        String apiSecret = env.get("SOLAPI_API_SECRET");
        String senderPhoneNumber = env.get("SOLAPI_SENDER_PHONE");
        String recipientPhoneNumber = env.getOrDefault("SMS_LIVE_TEST_TO", senderPhoneNumber);

        SolapiSmsSender sender = new SolapiSmsSender(apiKey, apiSecret, senderPhoneNumber);

        assertThatCode(() -> sender.sendVerificationCode(recipientPhoneNumber, TEST_CODE))
                .doesNotThrowAnyException();
    }

    private static Map<String, String> loadEnv() throws IOException {
        Map<String, String> values = new HashMap<>(System.getenv());
        if (!Files.exists(ENV_FILE)) {
            return values;
        }

        for (String line : Files.readAllLines(ENV_FILE, StandardCharsets.UTF_8)) {
            String trimmed = line.trim();
            if (trimmed.isEmpty() || trimmed.startsWith(COMMENT_PREFIX)) {
                continue;
            }

            int separator = trimmed.indexOf(KEY_VALUE_SEPARATOR);
            if (separator <= 0) {
                continue;
            }

            String key = trimmed.substring(0, separator).trim();
            String value = trimmed.substring(separator + 1).trim();
            if (!value.isEmpty()) {
                values.put(key, value);
            }
        }

        return values;
    }
}
