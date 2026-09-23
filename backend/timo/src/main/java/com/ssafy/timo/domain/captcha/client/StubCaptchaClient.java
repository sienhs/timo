package com.ssafy.timo.domain.captcha.client;

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.UUID;
import javax.imageio.ImageIO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * 네이버를 부르지 않는 캡차 구현체. {@code local} 과 {@code test} 에서 뜬다.
 *
 * <p>정답은 {@link #ANSWER} 하나로 고정이고, 이미지에도 그 글자를 그려 넣는다. 로컬에서 앱을 붙여
 * 보는 사람이 화면에 뜬 이미지를 그대로 읽어 입력할 수 있게 하려는 것이다 - {@code LoggingSmsSender}
 * 가 인증번호를 로그로 흘려 주는 것과 같은 목적이다.
 *
 * <p>{@code test} 를 빠뜨리면 안 된다. 통합 테스트는 {@code @ActiveProfiles("test")} 로 도는데,
 * 여기서 {@link NaverCaptchaClient} 가 뜨면 테스트가 실제 네이버를 두드린다.
 */
@Slf4j
@Component
@Profile({"local", "test"})
public class StubCaptchaClient implements CaptchaClient {

    /** 로컬·테스트의 고정 정답. 대소문자를 가리지 않는다. */
    public static final String ANSWER = "timo";

    private static final int WIDTH = 160;
    private static final int HEIGHT = 60;

    @Override
    public String issueKey() {
        String key = UUID.randomUUID().toString();
        log.warn("[CAPTCHA NOT ISSUED] key={}, answer={}", key, ANSWER);

        return key;
    }

    /**
     * 정답 글자를 그려 넣은 JPEG 을 만든다. 실제 이미지 형식으로 내보내야 앱이 받는 값의 모양이
     * 운영과 같아진다 - 아무 바이트나 돌려주면 로컬에서만 그림이 깨진다.
     */
    @Override
    public byte[] fetchImage(String key) {
        BufferedImage image = new BufferedImage(WIDTH, HEIGHT, BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = image.createGraphics();
        try {
            graphics.setColor(Color.WHITE);
            graphics.fillRect(0, 0, WIDTH, HEIGHT);
            graphics.setColor(Color.DARK_GRAY);
            graphics.setFont(new Font(Font.SANS_SERIF, Font.BOLD, 32));
            graphics.drawString(ANSWER, 24, 42);
        } finally {
            graphics.dispose();
        }

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try {
            ImageIO.write(image, "jpg", out);
        } catch (IOException e) {
            // 메모리로만 쓰는 스트림이라 실제로는 나올 수 없다.
            throw new UncheckedIOException("스텁 캡차 이미지 생성 실패", e);
        }
        return out.toByteArray();
    }

    @Override
    public boolean verify(String key, String value) {
        return ANSWER.equalsIgnoreCase(value);
    }
}
