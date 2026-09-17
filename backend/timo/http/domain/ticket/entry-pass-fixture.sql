-- 입장 QR(entry-pass.http · gate-entry.http)을 돌려 보기 위한 로컬 준비.
--
-- 티켓 자체는 로컬 시더가 만들어 준다(LocalDataSeeder.seedTickets - 시드 주문마다 OWNED 티켓
-- 한 장). 그래서 여기서 할 일은 두 가지뿐이다.
--
--   1) 공연 시작 시각을 입장 창(시작 -2h ~ +6h) 안으로 당긴다.
--      시드 공연 일정은 한참 뒤라 그냥 두면 발급이 409 "아직 입장 시간이 아닙니다" 로 막힌다.
--   2) 앞선 실행에서 소진된(USED) 티켓을 OWNED 로 되돌린다.
--      검표는 판정이 곧 소진이라 gate-entry.http 를 한 번 돌리면 그 티켓은 다시 못 쓴다.
--
-- 앱을 내리면 ddl-auto: create-drop 이라 DB 가 통째로 새로 깔린다. 그때는 시더가 티켓을 다시
-- 만들어 주지만 공연 시각은 원래대로 돌아가므로, 다시 띄웠으면 이 파일을 다시 돌린다.
--
-- 맨 아래 SELECT 가 찍어 주는 값을 .http 파일 맨 위 @ticketId · @concertId 에 넣는다.

-- seed001 의 PAID 주문 중 가장 빠른 한 건.
SET @rid = (
    SELECT r.reservation_id
      FROM reservation r
      JOIN login_info li ON li.member_id = r.member_id
     WHERE li.username = 'seed001'
       AND r.status = 'PAID'
     ORDER BY r.reservation_id
     LIMIT 1
);

SET @cid = (SELECT concert_id FROM reservation WHERE reservation_id = @rid);

-- 입장 창 안으로 당긴다.
UPDATE concert
   SET start_date = NOW() + INTERVAL 30 MINUTE
 WHERE concert_id = @cid;

-- 앞선 실행에서 입장 처리된 티켓을 되돌린다. 아직 안 썼으면 0행이라 아무 일도 없다.
UPDATE ticket
   SET status = 'OWNED'
 WHERE reservation_id = @rid
   AND status = 'USED';

-- 이 값들을 .http 파일 맨 위 변수에 넣는다.
SELECT t.ticket_id AS ticketId,
       @cid        AS concertId,
       @rid        AS reservationId,
       t.status    AS ticketStatus
  FROM ticket t
 WHERE t.reservation_id = @rid;
