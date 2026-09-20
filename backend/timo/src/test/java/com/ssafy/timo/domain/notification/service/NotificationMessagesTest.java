package com.ssafy.timo.domain.notification.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ssafy.timo.domain.notification.entity.NotificationPhase;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.NotificationMessages.ListedConcert;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.EnumSource;

/**
 * 알림 문구 조립의 경계를 확인한다. DB 도 스프링도 쓰지 않아서 가장 빠르고, 문구는 가장 자주 바뀌는 곳이라
 * 가장 자주 깨진다.
 *
 * <p>가장 위험한 것은 본문이 500자 컬럼을 넘는 것이다. 저장 쿼리가 넘친 본문을 오류 없이 잘라 넣기 때문에
 * 넘어도 알 방법이 없다. 그래서 어떤 입력에서도 상한을 넘지 않는지를 종류마다 본다.
 */
class NotificationMessagesTest {

    private static final LocalDateTime SOON = LocalDateTime.of(2026, 10, 1, 19, 0);

    /** 알림 본문 컬럼의 크기. 이 값을 넘으면 저장이 조용히 잘라 넣는다. */
    private static final int BODY_COLUMN_LIMIT = 500;

    // ---------------------------------------------------------------- 한 줄 문구

    @Test
    @DisplayName("입장 가능, 판매 완료 문구는 종류의 템플릿에 공연명을 채운다")
    void singleLineMessages_fillTheTypeTemplate() {
        assertThat(NotificationMessages.entryOpen("로이킴 콘서트")).isEqualTo("로이킴 콘서트, 지금부터 입장할 수 있어요");
        assertThat(NotificationMessages.listingSold("로이킴 콘서트")).isEqualTo("로이킴 콘서트 티켓이 판매됐어요");
    }

    @ParameterizedTest(name = "예매 오픈 {0} 은 \"{1}\" 로 나온다")
    @CsvSource({
            "D7, 공연 예매가 일주일 뒤 시작돼요",
            "D1, 공연 예매가 내일 시작돼요",
            "H1, 공연 예매 시작까지 1시간 남았어요"
    })
    @DisplayName("예매 오픈은 시점마다 요구사항이 확정한 문구가 그대로 나온다")
    void concertOpen_matchesConfirmedCopyPerPhase(NotificationPhase phase, String expected) {
        assertThat(NotificationMessages.concertOpen("공연", phase)).isEqualTo(expected);
    }

    @ParameterizedTest(name = "공연 일정 {0} 은 \"{1}\" 로 나온다")
    @CsvSource({
            "D7, 공연까지 일주일 남았어요",
            "D1, 내일은 공연 보는 날이에요",
            "D0, 오늘 공연 즐길 준비 되셨나요?"
    })
    @DisplayName("공연 일정은 시점마다 요구사항이 확정한 문구가 그대로 나온다")
    void showReminder_matchesConfirmedCopyPerPhase(NotificationPhase phase, String expected) {
        assertThat(NotificationMessages.showReminder("공연", phase)).isEqualTo(expected);
    }

    @Test
    @DisplayName("문구와 종류의 템플릿이 어긋나지 않는다")
    void messages_areBuiltFromTypeTemplates() {
        assertThat(NotificationMessages.entryOpen("A"))
                .isEqualTo(NotificationType.ENTRY_OPEN.template().formatted("A"));
        assertThat(NotificationMessages.listingSold("A"))
                .isEqualTo(NotificationType.LISTING_SOLD.template().formatted("A"));
        assertThat(NotificationMessages.concertOpen("A", NotificationPhase.D1))
                .isEqualTo(NotificationType.CONCERT_OPEN_REMINDER.templateFor(NotificationPhase.D1).formatted("A"));
        assertThat(NotificationMessages.showReminder("A", NotificationPhase.D1))
                .isEqualTo(NotificationType.SHOW_REMINDER.templateFor(NotificationPhase.D1).formatted("A"));
    }

    // ---------------------------------------------------------------- 마켓 알림: 나열 개수 경계

    @Test
    @DisplayName("공연이 하나도 없으면 만들지 않는다 — 보낼 알림이 없어야 한다")
    void market_noConcerts_isRejected() {
        assertThatThrownBy(() -> NotificationMessages.marketNewListing(List.of()))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> NotificationMessages.marketNewListing(null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("공연이 하나면 요약 줄 없이 한 줄이다")
    void market_oneConcert_isSingleLine() {
        String body = NotificationMessages.marketNewListing(concerts(1));

        assertThat(body).isEqualTo("공연1 양도 매물이 올라왔어요");
        assertThat(body).doesNotContain("\n");
    }

    @ParameterizedTest(name = "공연 {0}개이면 나열 {1}개, 접힌 줄 [{2}]")
    @CsvSource(value = {
            "2, 2, ",
            "3, 3, ",
            "4, 3, 외 1건",
            "5, 3, 외 2건",
            "10, 3, 외 7건"
    })
    @DisplayName("나열은 세 개까지이고 넘는 만큼은 외 N건으로 접는다")
    void market_listsUpToThreeAndFoldsTheRest(int count, int listed, String foldedLine) {
        List<String> lines = NotificationMessages.marketNewListing(concerts(count)).lines().toList();

        List<String> expected = new ArrayList<>();
        expected.add("찜한 공연 " + count + "건에 양도 매물이 올라왔어요");
        for (int i = 1; i <= listed; i++) {
            expected.add("· 공연" + i);
        }
        if (foldedLine != null) {
            expected.add("· " + foldedLine);
        }
        assertThat(lines).containsExactlyElementsOf(expected);
    }

    @Test
    @DisplayName("요약 줄의 건수는 나열한 개수가 아니라 전체 공연 수다")
    void market_headerCountsAllConcertsNotJustListed() {
        String header = NotificationMessages.marketNewListing(concerts(10)).lines().findFirst().orElseThrow();

        assertThat(header).isEqualTo("찜한 공연 10건에 양도 매물이 올라왔어요");
    }

    @Test
    @DisplayName("첫 줄이 요약이라 푸시가 접혀 첫 줄만 보여도 뜻이 통한다")
    void market_firstLineIsSelfContainedSummary() {
        String firstLine = NotificationMessages.marketNewListing(concerts(4)).lines().findFirst().orElseThrow();

        assertThat(firstLine).contains("양도 매물이 올라왔어요").doesNotContain("·");
    }

    @Test
    @DisplayName("줄바꿈은 개행 하나뿐이고 끝에 개행이 남지 않는다")
    void market_usesPlainNewlinesWithoutTrailingOne() {
        String body = NotificationMessages.marketNewListing(concerts(5));

        assertThat(body).doesNotContain("\r").doesNotEndWith("\n");
        assertThat(body.split("\n")).hasSize(5);
    }

    // ---------------------------------------------------------------- 마켓 알림: 정렬

    @Test
    @DisplayName("공연일이 임박한 순으로 나열한다")
    void market_listsSoonestConcertFirst() {
        List<ListedConcert> input = List.of(
                new ListedConcert("먼 공연", SOON.plusDays(30)),
                new ListedConcert("임박 공연", SOON.plusDays(1)),
                new ListedConcert("중간 공연", SOON.plusDays(10)));

        List<String> lines = NotificationMessages.marketNewListing(input).lines().toList();

        assertThat(lines.subList(1, 4)).containsExactly("· 임박 공연", "· 중간 공연", "· 먼 공연");
    }

    @Test
    @DisplayName("접히는 것은 가장 먼 공연들이다")
    void market_foldsTheFurthestConcerts() {
        List<ListedConcert> input = new ArrayList<>();
        for (int day = 5; day >= 1; day--) {
            input.add(new ListedConcert("D+" + day, SOON.plusDays(day)));
        }

        String body = NotificationMessages.marketNewListing(input);

        assertThat(body).contains("· D+1", "· D+2", "· D+3").doesNotContain("· D+4").doesNotContain("· D+5");
        assertThat(body).endsWith("· 외 2건");
    }

    @Test
    @DisplayName("시작 시각이 같으면 넘겨받은 순서를 지킨다")
    void market_tiesKeepInputOrder() {
        List<ListedConcert> input = List.of(
                new ListedConcert("가", SOON), new ListedConcert("나", SOON), new ListedConcert("다", SOON));

        assertThat(NotificationMessages.marketNewListing(input).lines().toList().subList(1, 4))
                .containsExactly("· 가", "· 나", "· 다");
    }

    @Test
    @DisplayName("넘겨받은 목록은 바꾸지 않는다")
    void market_doesNotMutateInput() {
        List<ListedConcert> input = new ArrayList<>(List.of(
                new ListedConcert("나중", SOON.plusDays(9)), new ListedConcert("먼저", SOON)));

        NotificationMessages.marketNewListing(input);

        assertThat(input).extracting(ListedConcert::title).containsExactly("나중", "먼저");
    }

    // ---------------------------------------------------------------- 공연명 절삭

    @Test
    @DisplayName("공연명이 정확히 30자면 그대로 두고, 31자부터 30자에서 자르고 말줄임표를 붙인다")
    void clip_boundaryAtThirtyCharacters() {
        String thirty = "가".repeat(30);
        String thirtyOne = "가".repeat(31);

        assertThat(NotificationMessages.clip(thirty)).isEqualTo(thirty);
        assertThat(NotificationMessages.clip(thirtyOne)).isEqualTo(thirty + "…");
    }

    @Test
    @DisplayName("짧은 공연명과 빈 공연명은 그대로다")
    void clip_leavesShortAndEmptyTitlesAlone() {
        assertThat(NotificationMessages.clip("A")).isEqualTo("A");
        assertThat(NotificationMessages.clip("")).isEmpty();
    }

    @Test
    @DisplayName("공연명이 없으면 알림을 만들 수 없다")
    void clip_nullTitle_isRejected() {
        assertThatThrownBy(() -> NotificationMessages.clip(null))
                .isInstanceOf(NullPointerException.class);
    }

    @Test
    @DisplayName("이모지처럼 두 칸을 차지하는 글자를 세는 기준이 글자 수이고, 절삭 지점에서 깨지지 않는다")
    void clip_countsCodePointsAndNeverSplitsSurrogatePairs() {
        String thirtyEmoji = "😀".repeat(30);
        String thirtyOneEmoji = "😀".repeat(31);

        assertThat(NotificationMessages.clip(thirtyEmoji)).as("30개는 UTF-16 으로 60칸이어도 그대로").isEqualTo(thirtyEmoji);
        String clipped = NotificationMessages.clip(thirtyOneEmoji);
        assertThat(clipped).isEqualTo(thirtyEmoji + "…");
        assertThat(new String(clipped.getBytes(StandardCharsets.UTF_8), StandardCharsets.UTF_8))
                .as("깨진 서로게이트가 있으면 인코딩 왕복에서 값이 달라진다").isEqualTo(clipped);
    }

    @Test
    @DisplayName("한글과 이모지가 섞여도 30글자 기준으로 자른다")
    void clip_mixedScripts() {
        String mixed = "가".repeat(29) + "😀😀";

        assertThat(NotificationMessages.clip(mixed)).isEqualTo("가".repeat(29) + "😀…");
    }

    @Test
    @DisplayName("모든 문구가 같은 절삭 규칙을 쓴다")
    void everyMessage_clipsTheTitle() {
        String clipped = "가".repeat(30) + "…";
        String longTitle = "가".repeat(45);

        assertThat(NotificationMessages.entryOpen(longTitle)).startsWith(clipped);
        assertThat(NotificationMessages.listingSold(longTitle)).startsWith(clipped);
        assertThat(NotificationMessages.concertOpen(longTitle, NotificationPhase.D7)).startsWith(clipped);
        assertThat(NotificationMessages.showReminder(longTitle, NotificationPhase.D7)).startsWith(clipped);
        assertThat(NotificationMessages.marketNewListing(List.of(new ListedConcert(longTitle, SOON))))
                .startsWith(clipped);
    }

    @Test
    @DisplayName("마켓 목록의 공연명도 각각 절삭된다")
    void market_clipsEachListedTitle() {
        String longTitle = "가".repeat(45);
        List<ListedConcert> input = List.of(
                new ListedConcert(longTitle, SOON), new ListedConcert("짧은 공연", SOON.plusDays(1)));

        assertThat(NotificationMessages.marketNewListing(input).lines().toList())
                .containsExactly("찜한 공연 2건에 양도 매물이 올라왔어요", "· " + "가".repeat(30) + "…", "· 짧은 공연");
    }

    // ---------------------------------------------------------------- 길이 상한

    @Test
    @DisplayName("어떤 종류의 문구도 아주 긴 공연명에서 본문 컬럼 크기를 넘지 않는다")
    void everyMessage_staysWithinBodyColumn_forHugeTitles() {
        String huge = "가".repeat(10_000);
        String hugeEmoji = "😀".repeat(10_000);

        for (String title : List.of(huge, hugeEmoji)) {
            assertThat(NotificationMessages.entryOpen(title)).hasSizeLessThanOrEqualTo(BODY_COLUMN_LIMIT);
            assertThat(NotificationMessages.listingSold(title)).hasSizeLessThanOrEqualTo(BODY_COLUMN_LIMIT);
            for (NotificationPhase phase : List.of(NotificationPhase.D7, NotificationPhase.D1, NotificationPhase.H1)) {
                assertThat(NotificationMessages.concertOpen(title, phase)).hasSizeLessThanOrEqualTo(BODY_COLUMN_LIMIT);
            }
            for (NotificationPhase phase : List.of(NotificationPhase.D7, NotificationPhase.D1, NotificationPhase.D0)) {
                assertThat(NotificationMessages.showReminder(title, phase)).hasSizeLessThanOrEqualTo(BODY_COLUMN_LIMIT);
            }
        }
    }

    @Test
    @DisplayName("마켓 알림은 공연이 수천 개에 제목이 전부 최대 길이여도 본문 컬럼 크기를 넘지 않는다")
    void market_staysWithinBodyColumn_forWorstCase() {
        for (String title : List.of("가".repeat(1_000), "😀".repeat(1_000))) {
            List<ListedConcert> input = new ArrayList<>();
            for (int i = 0; i < 5_000; i++) {
                input.add(new ListedConcert(title, SOON.plusMinutes(i)));
            }

            String body = NotificationMessages.marketNewListing(input);

            assertThat(body).hasSizeLessThanOrEqualTo(BODY_COLUMN_LIMIT);
            assertThat(body.lines().count()).as("요약 + 나열 3 + 접힌 줄").isEqualTo(5);
        }
    }

    // ---------------------------------------------------------------- 설계 상수

    @Test
    @DisplayName("문서에 정한 상수를 지킨다 — 공연명 30자, 나열 3개")
    void constants_matchDesign() {
        assertThat(NotificationMessages.TITLE_LIMIT).isEqualTo(30);
        assertThat(NotificationMessages.LIST_LIMIT).isEqualTo(3);
    }

    /** 제목이 "공연1" 부터이고 시작 시각이 하루씩 늦어지는 공연 n 개. */
    private static List<ListedConcert> concerts(int count) {
        List<ListedConcert> concerts = new ArrayList<>();
        for (int i = 1; i <= count; i++) {
            concerts.add(new ListedConcert("공연" + i, SOON.plusDays(i)));
        }
        return concerts;
    }
}
