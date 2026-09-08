package com.ssafy.timo.domain.auth.service;

import com.ssafy.timo.domain.auth.dto.SmsSendRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsSendResponseDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyResponseDto;
import com.ssafy.timo.domain.auth.exception.SmsAttemptExceededException;
import com.ssafy.timo.domain.auth.exception.SmsCodeMismatchException;
import com.ssafy.timo.domain.auth.exception.SmsCodeNotFoundException;
import com.ssafy.timo.domain.auth.exception.SmsSendLimitExceededException;
import com.ssafy.timo.domain.auth.repository.SmsVerificationStore;
import com.ssafy.timo.global.util.PhoneNumbers;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.HexFormat;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class SmsVerificationService {

    private static final Duration CODE_TTL = Duration.ofMinutes(3);
    /*
     * 인증을 통과한 뒤 이름·아이디·비밀번호·닉네임 네 단계를 더 지나야 가입 요청이 도착한다.
     * 아이디 확정 팝업까지 있어 10분으로는 마지막 단계에서 티켓이 만료되는 사람이 나온다.
     * 티켓은 32바이트 난수를 해시로 보관하는 1회용이라 이 정도 수명은 감당된다.
     */
    private static final Duration TICKET_TTL = Duration.ofMinutes(30);
    private static final Duration SEND_COOLDOWN = Duration.ofMinutes(1);
    private static final Duration DAILY_WINDOW = Duration.ofDays(1);
    private static final Duration IP_WINDOW = Duration.ofHours(1);

    private static final long DAILY_SEND_LIMIT = 5L;
    private static final long IP_SEND_LIMIT = 20L;
    private static final long MAX_VERIFY_ATTEMPTS = 5L;

    private static final int CODE_BOUND = 1_000_000;
    private static final String CODE_FORMAT = "%06d";
    private static final int TICKET_BYTES = 32;
    private static final String HASH_ALGORITHM = "SHA-256";

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final SmsVerificationStore smsVerificationStore;
    private final SmsSender smsSender;

    public SmsSendResponseDto sendCode(SmsSendRequestDto request, String clientIp) {
        String phoneNumber = PhoneNumbers.normalize(request.phoneNumber());

        checkSendLimit(phoneNumber, clientIp);

        String code = generateCode();
        smsSender.sendVerificationCode(phoneNumber, code);
        smsVerificationStore.saveCode(phoneNumber, hash(code), CODE_TTL);

        return new SmsSendResponseDto((int) CODE_TTL.toSeconds());
    }

    public SmsVerifyResponseDto verifyCode(SmsVerifyRequestDto request) {
        String phoneNumber = PhoneNumbers.normalize(request.phoneNumber());

        String storedCodeHash = smsVerificationStore.findCodeHash(phoneNumber)
                .orElseThrow(SmsCodeNotFoundException::new);

        if (!MessageDigest.isEqual(storedCodeHash.getBytes(StandardCharsets.UTF_8),
                hash(request.code()).getBytes(StandardCharsets.UTF_8))) {
            handleMismatch(phoneNumber);
        }

        smsVerificationStore.deleteCode(phoneNumber);

        String ticket = generateTicket();
        smsVerificationStore.saveTicket(hash(ticket), phoneNumber, TICKET_TTL);

        return new SmsVerifyResponseDto(ticket, (int) TICKET_TTL.toSeconds());
    }

    private void checkSendLimit(String phoneNumber, String clientIp) {
        if (smsVerificationStore.increaseIpCount(clientIp, IP_WINDOW) > IP_SEND_LIMIT) {
            log.warn("SMS send blocked by ip limit: clientIp={}", clientIp);
            throw new SmsSendLimitExceededException();
        }
        if (smsVerificationStore.increaseDailyCount(phoneNumber, DAILY_WINDOW) > DAILY_SEND_LIMIT) {
            log.warn("SMS send blocked by daily limit: phoneNumber={}", phoneNumber);
            throw new SmsSendLimitExceededException();
        }
        if (!smsVerificationStore.tryAcquireCooldown(phoneNumber, SEND_COOLDOWN)) {
            log.warn("SMS send blocked by cooldown: phoneNumber={}", phoneNumber);
            throw new SmsSendLimitExceededException();
        }
    }

    private void handleMismatch(String phoneNumber) {
        long attempts = smsVerificationStore.increaseAttempts(phoneNumber);
        if (attempts >= MAX_VERIFY_ATTEMPTS) {
            smsVerificationStore.deleteCode(phoneNumber);
            log.warn("SMS verification blocked by attempt limit: phoneNumber={}, attempts={}",
                    phoneNumber, attempts);
            throw new SmsAttemptExceededException();
        }
        throw new SmsCodeMismatchException();
    }

    private String generateCode() {
        return CODE_FORMAT.formatted(SECURE_RANDOM.nextInt(CODE_BOUND));
    }

    private String generateTicket() {
        byte[] bytes = new byte[TICKET_BYTES];
        SECURE_RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hash(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance(HASH_ALGORITHM);
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(HASH_ALGORITHM + " is not available", e);
        }
    }
}
