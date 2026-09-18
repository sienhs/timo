-- 취소 좌석의 랜덤 해제를 손으로 보기 위한 픽스처.
--
-- 실제 취소 API(DELETE /api/v1/reservations/{id})는 온체인 회수와 환불을 부르므로
-- 지갑이 없는 로컬 시드 계정으로는 500 이 난다. 그래서 "취소된 주문 + 해제 대기" 상태를
-- 여기서 직접 만든다. 보고 싶은 것은 취소 그 자체가 아니라 좌석이 언제 열리는가다.
--
-- 사용법
--   docker exec -i timo-mysql mysql -utimo -ptimo1234 timo < release-fixture.sql
--
-- 그 다음 reservation-cancel-release.http 를 돌린다.

-- ON_SALE 공연 하나에서 팔린 좌석 하나를 골라 "방금 취소됐고 10분 뒤 열린다" 로 바꾼다.
-- 10분은 실제 범위(3분 1초에서 15분) 안의 값이라 화면에서 보이는 모습이 같다.
UPDATE reservation r
    JOIN concert c ON c.concert_id = r.concert_id
SET r.status = 'CANCELLED',
    r.cancelled_at = NOW(6),
    r.seat_release_at = NOW(6) + INTERVAL 10 MINUTE
WHERE c.status = 'ON_SALE'
  AND r.status = 'PAID'
ORDER BY r.reservation_id
LIMIT 1;

-- 방금 바꾼 자리를 확인한다. 이 concert_id 와 seat_id 를 http 파일에 넣는다.
SELECT r.reservation_id,
       r.concert_id,
       r.seat_id,
       s.section_id,
       r.cancelled_at,
       r.seat_release_at
FROM reservation r
         JOIN seat s ON s.seat_id = r.seat_id
WHERE r.status = 'CANCELLED'
  AND r.seat_release_at > NOW(6)
ORDER BY r.reservation_id DESC
LIMIT 5;

-- 해제된 뒤의 모습을 보려면 위 자리의 해제 시각을 과거로 당긴다.
--   UPDATE reservation SET seat_release_at = NOW(6) - INTERVAL 1 SECOND
--    WHERE reservation_id = <위에서 나온 값>;
