-- 취소표 구매 기회(offer.http)를 돌려 보기 위한 로컬 준비.
--
-- 예매 취소 API 는 온체인 회수와 환불을 부르는데 시드 회원에게는 지갑이 없어 로컬에서 끝까지 가지 않는다.
-- 그래서 취소된 주문과 기회를 여기서 직접 만든다.
--
--   1) seed001 의 첫 PAID 주문을 취소 상태로 바꾸고 티켓을 REVOKED 로 돌린다.
--   2) 그 좌석에 seed002 를 당첨자로 하는 1시간 기회를 연다.
--   3) seed002 와 seed003 이 그 공연에 이미 가진 주문도 취소 상태로 돌린다. 시드는 회원마다 여러
--      공연의 티켓을 쥐고 있어, 안 돌리면 선점이 1인 1매(ALREADY_RESERVED)에 먼저 걸려 기회 판정을
--      보기 전에 끝난다. 실제 추첨은 보유자를 제외하므로 운영에서는 생기지 않는 상황이다.
--
-- seed003 은 기회를 받지 않는다. offer.http 가 "남은 그 자리를 못 잡는다" 를 볼 때 쓴다.
-- 앱을 다시 띄우면 create-drop 이라 전부 사라지니 다시 돌린다.
--
-- 실행: docker exec -i timo-mysql mysql -utimo -ptimo1234 timo < http/domain/offer/offer-fixture.sql

SET @seller   = (SELECT member_id FROM login_info WHERE username = 'seed001');
SET @winner   = (SELECT member_id FROM login_info WHERE username = 'seed002');
SET @stranger = (SELECT member_id FROM login_info WHERE username = 'seed003');
SET @rsv     = (SELECT MIN(reservation_id) FROM reservation WHERE member_id = @seller AND status = 'PAID');
SET @concert = (SELECT concert_id FROM reservation WHERE reservation_id = @rsv);
SET @seat    = (SELECT seat_id FROM reservation WHERE reservation_id = @rsv);

UPDATE reservation SET status = 'CANCELLED', cancelled_at = NOW(6), updated_at = NOW(6)
 WHERE reservation_id = @rsv;
UPDATE ticket SET status = 'REVOKED', updated_at = NOW(6)
 WHERE reservation_id = @rsv;

-- 3) 당첨자와 행인이 이 공연에 가진 주문을 비운다(1인 1매 통과용).
UPDATE ticket t JOIN reservation r ON r.reservation_id = t.reservation_id
   SET t.status = 'REVOKED', t.updated_at = NOW(6)
 WHERE r.concert_id = @concert AND r.member_id IN (@winner, @stranger) AND r.status = 'PAID';
UPDATE reservation SET status = 'CANCELLED', cancelled_at = NOW(6), updated_at = NOW(6)
 WHERE concert_id = @concert AND member_id IN (@winner, @stranger) AND status = 'PAID';

-- 같은 자리에 지난 기회가 남아 있으면 유니크 제약에 걸리므로 먼저 닫는다.
UPDATE cancel_offer SET status = 'EXPIRED', updated_at = NOW(6)
 WHERE concert_id = @concert AND seat_id = @seat AND status = 'OFFERED';

INSERT INTO cancel_offer (
    concert_id, seat_id, member_id, source_reservation_id, expires_at, status, reservation_id, created_at, updated_at
) VALUES (
    @concert, @seat, @winner, @rsv, NOW(6) + INTERVAL 1 HOUR, 'OFFERED', NULL, NOW(6), NOW(6)
);

SELECT @concert AS concert_id, @seat AS seat_id, @winner AS winner_member_id;
