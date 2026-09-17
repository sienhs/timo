-- 양도 매물의 등록 시각을 하루 당긴다. 매물은 등록 다음 날 20:00 에 올라가므로, 방금 등록한 매물은
-- 목록에 안 보이고 구매도 409 LISTING_NOT_OPEN_YET 다. 구매 흐름을 오늘 돌려 보려면 이걸로 당긴다.
--
-- market-success.http 의 "등록" 직후, "구매" 전에 실행한다. 판정은 서버 시계라 IDE 나 기기 시계를
-- 바꿔도 소용없고, 등록 시각을 바꾸는 것이 유일한 방법이다.
--
-- 앱을 내리면 ddl-auto: create-drop 이라 DB 가 통째로 새로 깔린다. 그러면 매물도 없어지니 등록부터 다시.
--
-- 실행: docker exec -i timo-mysql mysql -utimo -ptimo1234 timo < http/domain/market/market-fixture.sql

UPDATE ticket_listing
   SET listed_at = listed_at - INTERVAL 1 DAY
 WHERE status = 'LISTED'
   AND listed_at >= CURDATE();
