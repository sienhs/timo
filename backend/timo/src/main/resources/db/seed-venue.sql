-- 운영 카탈로그용 공연장 하나. seed-concerts.sql의 concert.venue_id=1이 이 행을 가리키므로,
-- data-locations 목록에서 반드시 seed-concerts.sql보다 앞에 와야 한다
-- (구역·좌석은 ProdCatalogSeeder가 기동 후 이 venue 위에 Java로 만든다).
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

INSERT INTO venue (venue_name, venue_address, total_seat_count, created_at, updated_at)
SELECT '고척돔', '서울시 구로구 경인로 430', 1000, NOW(6), NOW(6)
WHERE NOT EXISTS (SELECT 1 FROM venue WHERE venue_name = '고척돔');
