package com.ssafy.timo.domain.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 아이디·닉네임 중복 확인 API 통합 테스트.
 *
 * <p>엔드포인트를 하나로 두고 쿼리 파라미터로 가르는 방식이라, 잘못된 조합(둘 다 보냄 / 아무것도 안 보냄)이
 * 400 으로 걸러지는지까지 본다. 하나로 받는 대가로 그 검사가 필요해졌기 때문이다.
 */
@IntegrationTest
class AvailabilityApiIntegrationTest {

    private static final String PATH = "/api/v1/auth/availability";

    private static final String TAKEN_USERNAME = "timouser";
    private static final String TAKEN_NICKNAME = "티모";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private LoginInfoRepository loginInfoRepository;

    @Test
    @DisplayName("쓰지 않는 아이디면 available true")
    void freeUsername() throws Exception {
        mvc.perform(get(PATH).param("username", "brand_new"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.available").value(true));
    }

    @Test
    @DisplayName("이미 쓰는 아이디면 available false")
    void takenUsername() throws Exception {
        seed();

        mvc.perform(get(PATH).param("username", TAKEN_USERNAME))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.available").value(false));
    }

    @Test
    @DisplayName("쓰지 않는 닉네임이면 available true")
    void freeNickname() throws Exception {
        mvc.perform(get(PATH).param("nickname", "새닉네임"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.available").value(true));
    }

    @Test
    @DisplayName("이미 쓰는 닉네임이면 available false")
    void takenNickname() throws Exception {
        seed();

        mvc.perform(get(PATH).param("nickname", TAKEN_NICKNAME))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.available").value(false));
    }

    @Test
    @DisplayName("아이디와 닉네임은 서로 다른 공간이라 같은 문자열이 겹쳐도 각각 판정한다")
    void usernameAndNicknameAreSeparate() throws Exception {
        seed();

        // 아이디로 쓰인 문자열을 닉네임으로 물으면 사용 가능해야 한다.
        // (양쪽 형식을 모두 통과하는 문자열이어야 이 검증이 성립한다. 밑줄은 닉네임에서 허용되지 않는다.)
        mvc.perform(get(PATH).param("username", TAKEN_USERNAME))
                .andExpect(jsonPath("$.available").value(false));
        mvc.perform(get(PATH).param("nickname", TAKEN_USERNAME))
                .andExpect(jsonPath("$.available").value(true));
    }

    @Test
    @DisplayName("응답을 캐싱하지 못하게 막는다")
    void doesNotAllowCaching() throws Exception {
        // 캐싱되면 남이 채간 아이디를 계속 사용 가능하다고 답한다.
        mvc.perform(get(PATH).param("username", "brand_new"))
                .andExpect(header().string(HttpHeaders.CACHE_CONTROL, "no-store"));
    }

    @Test
    @DisplayName("아무것도 보내지 않으면 400 과 함께 이유를 알려준다")
    void rejectsMissingParameter() throws Exception {
        mvc.perform(get(PATH))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].reason").value("username 과 nickname 중 하나만 보내야 합니다."));
    }

    @Test
    @DisplayName("둘을 함께 보내면 400")
    void rejectsBothParameters() throws Exception {
        mvc.perform(get(PATH)
                        .param("username", "brand_new")
                        .param("nickname", "새닉네임"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].reason").value("username 과 nickname 중 하나만 보내야 합니다."));
    }

    @Test
    @DisplayName("형식에 맞지 않는 아이디는 어느 필드가 틀렸는지 알려준다")
    void rejectsMalformedUsername() throws Exception {
        // 앱이 해당 입력칸에 표시할 수 있도록 field 가 실려 나가야 한다.
        // 엔드포인트를 하나로 합쳐도 이게 유지되는 것이 이 설계의 전제였다.
        mvc.perform(get(PATH).param("username", "1abc"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("username"));
    }

    @Test
    @DisplayName("형식에 맞지 않는 닉네임은 어느 필드가 틀렸는지 알려준다")
    void rejectsMalformedNickname() throws Exception {
        mvc.perform(get(PATH).param("nickname", "티 모"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("nickname"));
    }

    private void seed() {
        Member member = memberRepository.save(Member.builder()
                .phoneNumber("01012345678")
                .name("정희성")
                .nickname(TAKEN_NICKNAME)
                .build());
        loginInfoRepository.saveAndFlush(LoginInfo.builder()
                .member(member)
                .username(TAKEN_USERNAME)
                .passwordHash("$2a$10$dummyhashdummyhashdummyhashdummyhash")
                .build());
    }
}
