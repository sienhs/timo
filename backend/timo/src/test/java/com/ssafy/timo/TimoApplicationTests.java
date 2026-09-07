package com.ssafy.timo;

import com.ssafy.timo.support.IntegrationTest;
import org.junit.jupiter.api.Test;

/**
 * 애플리케이션 컨텍스트가 뜨는지 확인한다.
 *
 * <p>통합 테스트와 같은 설정({@link IntegrationTest})을 쓴다. 여기서만 다른 애노테이션 조합을 쓰면
 * 그 조합으로 컨텍스트가 한 번 더 뜬다.
 */
@IntegrationTest
class TimoApplicationTests {

    @Test
    void contextLoads() {
    }
}
