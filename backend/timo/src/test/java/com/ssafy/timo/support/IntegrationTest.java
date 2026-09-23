package com.ssafy.timo.support;

import com.ssafy.timo.domain.captcha.CaptchaProbeConfig;
import com.ssafy.timo.global.exception.ExceptionProbeConfig;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Inherited;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 모든 통합 테스트가 공유하는 단일 스프링 컨텍스트.
 *
 * <p>스프링 테스트는 <b>설정이 완전히 같은</b> 테스트끼리만 컨텍스트를 재사용한다.
 * 슬라이스 애노테이션({@code @WebMvcTest}, {@code @DataJpaTest})이나 {@code @MockitoBean} 을
 * 테스트마다 다르게 붙이면 그 조합마다 컨텍스트가 새로 떠서 실행 시간이 배로 늘어난다.
 * 그래서 설정을 이 애노테이션 하나로 고정하고, 모든 통합 테스트는 이것만 붙인다.
 * 부팅은 전체 실행에서 한 번이다.
 *
 * <p>지켜야 할 것:
 * <ul>
 *   <li>{@code @MockitoBean} / {@code @MockitoSpyBean} 을 쓰지 않는다. 빈을 갈아끼우는 순간
 *       그 테스트만 별도 컨텍스트를 쓴다. 협력 객체를 가짜로 바꿔야 하는 검증은
 *       {@code @ExtendWith(MockitoExtension.class)} 단위 테스트로 남긴다.</li>
 *   <li>{@code @DirtiesContext} 를 쓰지 않는다. 캐시된 컨텍스트를 버려 이후 테스트가 다시 부팅한다.</li>
 *   <li>{@code @TestPropertySource} 로 속성을 덮지 않는다. 속성이 다르면 다른 컨텍스트가 된다.
 *       공통 설정은 {@code src/test/resources/application-test.yml} 에 넣는다.</li>
 * </ul>
 *
 * <p>{@code @Transactional} 이 붙어 있어 각 테스트가 끝나면 롤백된다. 컨텍스트를 공유해도
 * 테스트 간 데이터가 섞이지 않으므로 별도의 정리 코드가 필요 없다.
 *
 * <p>{@code addFilters = false} 로 시큐리티 필터 체인을 태우지 않는다. test 프로필에서도
 * 운영 {@code SecurityConfig} 가 활성이라 {@code anyRequest().authenticated()} 정책이 걸리는데,
 * 도메인 API 통합 테스트의 관심사는 인가가 아니라 상태 코드와 응답 스키마이기 때문이다.
 *
 * <p>따라서 <b>인가 정책은 이 애노테이션으로 검증되지 않는다.</b> 엔드포인트별 권한 규칙과
 * 401/403 응답 스키마는 필터 체인을 실제로 태우는 별도 테스트에서 다뤄야 한다.
 *
 * <p>{@link MarketHoursTestConfig} 도 함께 올린다. 양도 마켓 운영 시간 판정만 {@link MarketClock} 으로
 * 조립해, 공용 {@code Clock} 을 건드리지 않고도 테스트가 창 안팎을 오갈 수 있게 한다.
 *
 * <p>{@link ExceptionProbeConfig} 를 함께 올린다. 예외 처리 규약은 도메인 컨트롤러가 아니라
 * 전용 프로브 컨트롤러로 검증해야 하는데, 그것만 따로 등록하면 컨텍스트가 하나 더 뜨기 때문이다.
 * 프로브는 테스트 소스에만 있고 {@code /test/**} 경로만 쓴다.
 *
 * <p>{@link CaptchaProbeConfig} 도 같은 이유로 함께 올린다. {@code RequireCaptchaInterceptor} 의
 * 동작을 도메인 API(좌석 조회, B9)와 무관하게 확인한다.
 */
@Documented
@Inherited
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import({ExceptionProbeConfig.class, MarketHoursTestConfig.class, CaptchaProbeConfig.class})
@Transactional
public @interface IntegrationTest {
}
