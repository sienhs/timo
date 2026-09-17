-- 현재 JPA 엔티티 기준의 빈 스키마 초기화 파일이다.
-- JPA 엔티티가 선언한 UNIQUE 제약과 조회 경로의 보조 인덱스는 함께 만든다.
-- FOREIGN KEY는 애플리케이션의 기존 참조 방식에 맞춰 만들지 않는다.
-- 기존 테이블을 삭제하지 않으므로, 빈 데이터베이스에서 한 번만 실행한다.

CREATE TABLE `member` (
    `member_id` BIGINT NOT NULL AUTO_INCREMENT,
    `role` VARCHAR(20) NOT NULL,
    `phone_number` VARCHAR(20) NOT NULL,
    `status` VARCHAR(20) NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `nickname` VARCHAR(30) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`member_id`),
    UNIQUE KEY `uk_member_phone_number` (`phone_number`),
    UNIQUE KEY `uk_member_nickname` (`nickname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `venue` (
    `venue_id` BIGINT NOT NULL AUTO_INCREMENT,
    `venue_name` VARCHAR(10) NULL,
    `venue_address` VARCHAR(255) NULL,
    `total_seat_count` INT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`venue_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `artist` (
    `artist_id` BIGINT NOT NULL AUTO_INCREMENT,
    `artist_name` VARCHAR(200) NULL,
    `profile_image` TEXT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`artist_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `concert` (
    `concert_id` BIGINT NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(200) NOT NULL,
    `genre` VARCHAR(255) NOT NULL,
    `poster_image_key` VARCHAR(500) NULL,
    `description` TEXT NULL,
    `age_rating` VARCHAR(255) NOT NULL,
    `status` VARCHAR(255) NOT NULL,
    `view_count` INT NOT NULL,
    `start_date` DATETIME(6) NULL,
    `end_date` DATETIME(6) NULL,
    `open_at` DATETIME(6) NULL,
    `venue_id` BIGINT NOT NULL,
    `organizer_id` BIGINT NULL,
    `face_price` DECIMAL(38,0) NULL,
    `show_id` DECIMAL(38,0) NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`concert_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `section` (
    `section_id` BIGINT NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(50) NOT NULL,
    `grade` VARCHAR(255) NOT NULL,
    `price` INT NOT NULL,
    `seat_count` INT NOT NULL,
    `row_count` INT NULL,
    `seat_per_row` INT NULL,
    `venue_id` BIGINT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`section_id`),
    UNIQUE KEY `uk_section_venue_name` (`venue_id`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `seat` (
    `seat_id` BIGINT NOT NULL AUTO_INCREMENT,
    `seat_no` INT NOT NULL,
    `seat_col` INT NOT NULL,
    `section_id` BIGINT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`seat_id`),
    UNIQUE KEY `uk_seat_section_position` (`section_id`, `seat_no`, `seat_col`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `concert_artist` (
    `concert_artist_id` BIGINT NOT NULL AUTO_INCREMENT,
    `concert_id` BIGINT NOT NULL,
    `artist_id` BIGINT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`concert_artist_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `concert_image` (
    `concert_image_id` BIGINT NOT NULL AUTO_INCREMENT,
    `concert_id` BIGINT NOT NULL,
    `image_key` VARCHAR(500) NOT NULL,
    `sort_order` INT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`concert_image_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `login_info` (
    `member_id` BIGINT NOT NULL,
    `username` VARCHAR(50) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`member_id`),
    UNIQUE KEY `uk_login_info_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `wallet` (
    `member_id` BIGINT NOT NULL,
    `address` VARCHAR(42) NOT NULL,
    `encrypted_keystore_json` TEXT NOT NULL,
    `wrapped_dek` VARCHAR(255) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `refresh_token` (
    `refresh_token_id` BIGINT NOT NULL AUTO_INCREMENT,
    `member_id` BIGINT NOT NULL,
    `device_id` VARCHAR(64) NOT NULL,
    `token_hash` VARCHAR(64) NOT NULL,
    `expires_at` DATETIME(6) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`refresh_token_id`),
    UNIQUE KEY `uk_refresh_token_member_device` (`member_id`, `device_id`),
    UNIQUE KEY `uk_refresh_token_hash` (`token_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 예약별 온체인 NFT 발행 상태. token_id와 reservation_id는 각각 하나의 티켓에만 대응한다.
CREATE TABLE `ticket` (
    `ticket_id` BIGINT NOT NULL AUTO_INCREMENT,
    `reservation_id` BIGINT NOT NULL,
    `token_id` DECIMAL(38,0) NULL,
    `mint_tx_hash` VARCHAR(66) NULL,
    `mint_attempt_count` INT NOT NULL,
    `failure_reason` VARCHAR(500) NULL,
    `status` VARCHAR(255) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`ticket_id`),
    UNIQUE KEY `uk_ticket_token_id` (`token_id`),
    UNIQUE KEY `uk_ticket_reservation` (`reservation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 온체인 지갑 잔액의 화면용 오프체인 거래 이력.
CREATE TABLE `wallet_transaction` (
    `wallet_transaction_id` BIGINT NOT NULL AUTO_INCREMENT,
    `member_id` BIGINT NOT NULL,
    `title` VARCHAR(200) NOT NULL,
    `amount` DECIMAL(38,0) NOT NULL,
    `balance_after` DECIMAL(38,0) NOT NULL,
    `source` VARCHAR(100) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`wallet_transaction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 공연별 좌석 선점 이력. HELD 상태인 행만 생성 컬럼을 통해 유일하게 만든다.
CREATE TABLE `seat_hold` (
    `seat_hold_id` BIGINT NOT NULL AUTO_INCREMENT,
    `concert_id` BIGINT NOT NULL,
    `seat_id` BIGINT NOT NULL,
    `member_id` BIGINT NOT NULL,
    `expires_at` DATETIME(6) NOT NULL,
    `released_at` DATETIME(6) NULL,
    `status` VARCHAR(20) NOT NULL,
    `active_seat` BIGINT GENERATED ALWAYS AS (IF(`status` = 'HELD', `seat_id`, NULL)) STORED,
    `active_member` BIGINT GENERATED ALWAYS AS (IF(`status` = 'HELD', `member_id`, NULL)) STORED,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`seat_hold_id`),
    UNIQUE KEY `uk_hold_seat` (`concert_id`, `active_seat`),
    UNIQUE KEY `uk_hold_member` (`concert_id`, `active_member`),
    KEY `ix_hold_expire` (`status`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 결제된 예매와 취소 이력. PAID 상태인 행만 좌석·회원별로 유일하다.
CREATE TABLE `reservation` (
    `reservation_id` BIGINT NOT NULL AUTO_INCREMENT,
    `concert_id` BIGINT NOT NULL,
    `member_id` BIGINT NOT NULL,
    `seat_id` BIGINT NOT NULL,
    `cancelled_at` DATETIME(6) NULL,
    `status` VARCHAR(20) NOT NULL,
    `active_seat` BIGINT GENERATED ALWAYS AS (IF(`status` = 'PAID', `seat_id`, NULL)) STORED,
    `active_member` BIGINT GENERATED ALWAYS AS (IF(`status` = 'PAID', `member_id`, NULL)) STORED,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`reservation_id`),
    UNIQUE KEY `uk_rsv_seat` (`concert_id`, `active_seat`),
    UNIQUE KEY `uk_rsv_member` (`concert_id`, `active_member`),
    KEY `ix_rsv_member` (`member_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 티켓 양도 매물. ticket_id는 응답에 내보내지 않는 내부 식별자다.
CREATE TABLE `ticket_listing` (
    `listing_id` BIGINT NOT NULL AUTO_INCREMENT,
    `ticket_id` BIGINT NOT NULL,
    `seller_member_id` BIGINT NOT NULL,
    `concert_id` BIGINT NOT NULL,
    `section_id` BIGINT NOT NULL,
    `seat_no` INT NOT NULL,
    `seat_col` INT NOT NULL,
    `price` BIGINT NOT NULL,
    `face_value` BIGINT NOT NULL,
    `status` VARCHAR(20) NOT NULL,
    `listed_at` DATETIME(6) NOT NULL,
    `closed_at` DATETIME(6) NULL,
    `active_ticket` BIGINT GENERATED ALWAYS AS (IF(`status` = 'LISTED', `ticket_id`, NULL)) STORED,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`listing_id`),
    KEY `idx_listing_concert_status_price` (`concert_id`, `status`, `price`),
    KEY `idx_listing_seller_status` (`seller_member_id`, `status`),
    KEY `idx_listing_ticket` (`ticket_id`),
    UNIQUE KEY `uk_listing_ticket_active` (`active_ticket`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 티켓 양도 체결 이력. 하나의 매물은 한 번만 체결할 수 있다.
CREATE TABLE `ticket_trade` (
    `trade_id` BIGINT NOT NULL AUTO_INCREMENT,
    `listing_id` BIGINT NOT NULL,
    `ticket_id` BIGINT NOT NULL,
    `seller_member_id` BIGINT NOT NULL,
    `buyer_member_id` BIGINT NOT NULL,
    `price` BIGINT NOT NULL,
    `traded_at` DATETIME(6) NOT NULL,
    `status` VARCHAR(20) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`trade_id`),
    UNIQUE KEY `uk_ticket_trade_listing` (`listing_id`),
    KEY `idx_trade_buyer` (`buyer_member_id`, `traded_at`),
    KEY `idx_trade_ticket` (`ticket_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 즉시 좌석 선점 부하 테스트를 할 수 있는 단일 공연장·공연·구역·좌석 1,000석.
INSERT INTO `venue` (
    `venue_name`, `venue_address`, `total_seat_count`, `created_at`, `updated_at`
) VALUES (
    'LOAD TEST', 'load-test-only', 1000, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @load_test_venue_id = LAST_INSERT_ID();

INSERT INTO `concert` (
    `title`, `genre`, `poster_image_key`, `description`, `age_rating`, `status`, `view_count`,
    `start_date`, `end_date`, `open_at`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    'Load Test Concert', 'CONCERT', NULL, 'RDS load-test fixture', 'ALL', 'ON_SALE', 0,
    CURRENT_TIMESTAMP(6), DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL 1 DAY), CURRENT_TIMESTAMP(6),
    @load_test_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);

INSERT INTO `section` (
    `name`, `grade`, `price`, `seat_count`, `row_count`, `seat_per_row`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    'LOAD', 'COMMON', 10000, 1000, 20, 50, @load_test_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @load_test_section_id = LAST_INSERT_ID();

INSERT INTO `seat` (
    `seat_no`, `seat_col`, `section_id`, `created_at`, `updated_at`
)
SELECT
    FLOOR(numbers.n / 50) + 1,
    MOD(numbers.n, 50) + 1,
    @load_test_section_id,
    CURRENT_TIMESTAMP(6),
    CURRENT_TIMESTAMP(6)
FROM (
    SELECT ones.digit + tens.digit * 10 + hundreds.digit * 100 AS n
    FROM
        (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS ones
    CROSS JOIN
        (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS tens
    CROSS JOIN
        (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS hundreds
) AS numbers;

-- 부하 테스트용 회원 100,000명. 빈 데이터베이스를 전제로 한 초기화 파일이므로
-- 중복 실행하지 않는다. 로그인 정보·지갑·리프레시 토큰은 만들지 않는다.
-- 좌석 선점 API의 요청자 식별은 JWT subject를 사용하므로, 부하 생성기는 이 member_id 범위로
-- 유효한 테스트 JWT를 발급해 사용한다.
INSERT INTO `member` (
    `role`, `phone_number`, `status`, `name`, `nickname`, `created_at`, `updated_at`
)
SELECT
    'USER',
    CONCAT('010', LPAD(numbers.n, 8, '0')),
    'ACTIVE',
    CONCAT('load-test-member-', numbers.n),
    CONCAT('load-', numbers.n),
    CURRENT_TIMESTAMP(6),
    CURRENT_TIMESTAMP(6)
FROM (
    SELECT
        ones.digit
        + tens.digit * 10
        + hundreds.digit * 100
        + thousands.digit * 1000
        + ten_thousands.digit * 10000
        + 1 AS n
    FROM
        (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS ones
    CROSS JOIN
        (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS tens
    CROSS JOIN
        (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS hundreds
    CROSS JOIN
        (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS thousands
    CROSS JOIN
        (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS ten_thousands
) AS numbers;

-- k6의 인증 준비용 계정 1,000개. 10만 회원 전체를 로그인 가능하게 만들면
-- BCrypt 검증·토큰 발급 부하가 핵심 API 측정에 섞인다. k6 setup()은 이 계정들로
-- 한 번씩만 로그인하고, 램프 구간에서는 받은 access token만 사용한다.
--
-- PasswordEncoder(BCrypt)의 검증값은 "password"다. 부하테스트 전용 RDS에서만
-- 사용하며, 운영 자격 증명이나 JWT 비밀키를 테스트 스크립트에 넣지 않는다.
INSERT INTO `login_info` (
    `member_id`, `username`, `password_hash`, `created_at`, `updated_at`
)
SELECT
    `member_id`,
    CONCAT('loadtest', LPAD(`member_id`, 4, '0')),
    '$2b$10$M4vw0C.ttFr3B8XhCWUsOuiSVms7TDwuXtLI6BREh2GVr5ijw3CiO',
    CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
FROM `member`
WHERE `member_id` BETWEEN 1 AND 1000;

-- 로컬 LocalDataSeeder와 같은 화면 확인용 데모 데이터.
-- 부하 테스트용 단일 공연장/공연과 섞이지 않도록 별도 공연장과 좌석을 만든다.
-- 이 블록은 DB 행만 초기화한다. 실제 ShowRegistry 등록과 지갑 생성은 수행하지 않으므로
-- 시드 티켓의 token_id/mint_tx_hash는 LocalDataSeeder와 마찬가지로 체인에 없는 더미 값이다.

INSERT INTO `artist` (`artist_name`, `profile_image`, `created_at`, `updated_at`)
VALUES ('김필', 'artist/artist_kim_feel.jpg', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @demo_artist_kim_feel_id = LAST_INSERT_ID();

INSERT INTO `artist` (`artist_name`, `profile_image`, `created_at`, `updated_at`)
VALUES ('이승기', 'artist/artist_lee_s.jpg', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @demo_artist_lee_id = LAST_INSERT_ID();

INSERT INTO `artist` (`artist_name`, `profile_image`, `created_at`, `updated_at`)
VALUES ('로이킴', 'artist/artist_roykim.jpg', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @demo_artist_roy_id = LAST_INSERT_ID();

INSERT INTO `artist` (`artist_name`, `profile_image`, `created_at`, `updated_at`)
VALUES ('Bruno Mars', 'artist/artist_bruno_mars.jpg', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
SET @demo_artist_mars_id = LAST_INSERT_ID();

INSERT INTO `venue` (
    `venue_name`, `venue_address`, `total_seat_count`, `created_at`, `updated_at`
) VALUES (
    '고척돔', '서울시 구로구 경인로 430', 1000, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_venue_id = LAST_INSERT_ID();

INSERT INTO `section` (
    `name`, `grade`, `price`, `seat_count`, `row_count`, `seat_per_row`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    'A구역', 'COMMON', 150000, 200, 10, 20, @demo_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_section_a_id = LAST_INSERT_ID();

INSERT INTO `section` (
    `name`, `grade`, `price`, `seat_count`, `row_count`, `seat_per_row`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    'B구역', 'COMMON', 150000, 200, 10, 20, @demo_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_section_b_id = LAST_INSERT_ID();

INSERT INTO `section` (
    `name`, `grade`, `price`, `seat_count`, `row_count`, `seat_per_row`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    'C구역', 'COMMON', 120000, 200, 10, 20, @demo_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_section_c_id = LAST_INSERT_ID();

INSERT INTO `section` (
    `name`, `grade`, `price`, `seat_count`, `row_count`, `seat_per_row`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    '2층 D구역', 'COMMON', 120000, 200, 10, 20, @demo_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_section_d_id = LAST_INSERT_ID();

INSERT INTO `section` (
    `name`, `grade`, `price`, `seat_count`, `row_count`, `seat_per_row`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    '2층 E구역', 'COMMON', 99000, 200, 10, 20, @demo_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_section_e_id = LAST_INSERT_ID();

CREATE TEMPORARY TABLE `demo_seed_number` (
    `n` INT NOT NULL,
    PRIMARY KEY (`n`)
);

INSERT INTO `demo_seed_number` (`n`)
SELECT
    ones.digit + tens.digit * 10 + hundreds.digit * 100 + 1
FROM
    (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS ones
CROSS JOIN
    (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS tens
CROSS JOIN
    (SELECT 0 AS digit UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS hundreds;

INSERT INTO `seat` (`seat_no`, `seat_col`, `section_id`, `created_at`, `updated_at`)
SELECT
    FLOOR((numbers.n - 1) / 20) + 1,
    MOD(numbers.n - 1, 20) + 1,
    sections.section_id,
    CURRENT_TIMESTAMP(6),
    CURRENT_TIMESTAMP(6)
FROM `demo_seed_number` AS numbers
CROSS JOIN (
    SELECT @demo_section_a_id AS section_id
    UNION ALL SELECT @demo_section_b_id
    UNION ALL SELECT @demo_section_c_id
    UNION ALL SELECT @demo_section_d_id
    UNION ALL SELECT @demo_section_e_id
) AS sections
WHERE numbers.n <= 200;

INSERT INTO `concert` (
    `title`, `genre`, `poster_image_key`, `description`, `age_rating`, `status`, `view_count`,
    `start_date`, `end_date`, `open_at`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    '김필 단독 콘서트', 'CONCERT', 'poster/poster_main_kim_feel.gif', '김필 단독 콘서트',
    'AGE_7', 'CLOSED', 1203, '2026-07-10 19:00:00', '2026-07-10 21:00:00',
    '2026-06-01 20:00:00', @demo_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_concert_kim_feel_id = LAST_INSERT_ID();

INSERT INTO `concert` (
    `title`, `genre`, `poster_image_key`, `description`, `age_rating`, `status`, `view_count`,
    `start_date`, `end_date`, `open_at`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    '이승기 콘서트', 'CONCERT', 'poster/poster_main_lee.gif', '이승기 단독 콘서트',
    'ALL', 'SCHEDULED', 512, '2026-11-21 18:00:00', '2026-11-21 21:00:00',
    '2026-10-15 20:00:00', @demo_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_concert_lee_id = LAST_INSERT_ID();

INSERT INTO `concert` (
    `title`, `genre`, `poster_image_key`, `description`, `age_rating`, `status`, `view_count`,
    `start_date`, `end_date`, `open_at`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    '로이킴 콘서트', 'CONCERT', 'poster/poster_main_roykim.jpg', '로이킴 단독 콘서트',
    'AGE_7', 'ON_SALE', 3300, '2026-09-20 19:30:00', '2026-09-20 21:30:00',
    '2026-08-01 14:00:00', @demo_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_concert_roy_id = LAST_INSERT_ID();

INSERT INTO `concert` (
    `title`, `genre`, `poster_image_key`, `description`, `age_rating`, `status`, `view_count`,
    `start_date`, `end_date`, `open_at`, `venue_id`, `created_at`, `updated_at`
) VALUES (
    'Bruno Mars 내한공연', 'CONCERT', 'poster/poster_main_mars.gif', 'Bruno Mars 내한 단독 공연',
    'ALL', 'ON_SALE', 87, '2026-12-05 19:00:00', '2026-12-05 21:00:00',
    '2026-09-01 20:00:00', @demo_venue_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)
);
SET @demo_concert_mars_id = LAST_INSERT_ID();

INSERT INTO `concert_artist` (`concert_id`, `artist_id`, `created_at`, `updated_at`)
VALUES
    (@demo_concert_kim_feel_id, @demo_artist_kim_feel_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)),
    (@demo_concert_lee_id, @demo_artist_lee_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)),
    (@demo_concert_roy_id, @demo_artist_roy_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)),
    (@demo_concert_mars_id, @demo_artist_mars_id, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

INSERT INTO `concert_image` (`concert_id`, `image_key`, `sort_order`, `created_at`, `updated_at`)
VALUES
    (@demo_concert_kim_feel_id, 'detail/poster_detail_kim.jpg', 0, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)),
    (@demo_concert_lee_id, 'detail/poster_detail_lee.jpg', 0, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)),
    (@demo_concert_mars_id, 'detail/poster_detail_mars.jpg', 0, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));

-- 전체 회원 수 100,000명을 유지하기 위해 로그인 정보가 없는 부하 테스트 회원 1001~1180을
-- 공연별 판매 110석과 선점 70석에 공통으로 사용할 데모 회원으로 바꾼다.
UPDATE `member` AS members
JOIN `demo_seed_number` AS numbers ON members.member_id = 1000 + numbers.n
SET
    members.phone_number = CONCAT('0109900', LPAD(numbers.n, 4, '0')),
    members.name = CONCAT('시드회원', numbers.n),
    members.nickname = CONCAT('시드', numbers.n),
    members.updated_at = CURRENT_TIMESTAMP(6)
WHERE numbers.n <= 180;

-- BCrypt 검증값은 "timo1234!"다. LocalDataSeeder와 동일하게 모든 시드 계정이 해시를 공유한다.
INSERT INTO `login_info` (`member_id`, `username`, `password_hash`, `created_at`, `updated_at`)
SELECT
    members.member_id,
    CONCAT('seed', LPAD(numbers.n, 3, '0')),
    '$2a$10$fvasJOTd65D.oq4VoAw7duO/eCXCjSSsHBLzskVAY2I.EspGeCQeS',
    CURRENT_TIMESTAMP(6),
    CURRENT_TIMESTAMP(6)
FROM `demo_seed_number` AS numbers
JOIN `member` AS members ON members.member_id = 1000 + numbers.n
WHERE numbers.n <= 180;

-- 구역 안에서 9번째마다 판매 완료로 둔다. 각 공연에서 22석 x 5구역 = 110석이다.
INSERT INTO `reservation` (
    `concert_id`, `member_id`, `seat_id`, `cancelled_at`, `status`, `created_at`, `updated_at`
)
SELECT
    concerts.concert_id,
    members.member_id,
    seats.seat_id,
    NULL,
    'PAID',
    CURRENT_TIMESTAMP(6),
    CURRENT_TIMESTAMP(6)
FROM (
    SELECT @demo_concert_roy_id AS concert_id
    UNION ALL SELECT @demo_concert_mars_id
) AS concerts
CROSS JOIN (
    SELECT @demo_section_a_id AS section_id, 0 AS section_index
    UNION ALL SELECT @demo_section_b_id, 1
    UNION ALL SELECT @demo_section_c_id, 2
    UNION ALL SELECT @demo_section_d_id, 3
    UNION ALL SELECT @demo_section_e_id, 4
) AS sections
JOIN `seat` AS seats ON seats.section_id = sections.section_id
JOIN `member` AS members
  ON members.phone_number = CONCAT(
      '0109900',
      LPAD(sections.section_index * 22 + FLOOR(((seats.seat_no - 1) * 20 + seats.seat_col) / 9), 4, '0')
  )
WHERE MOD((seats.seat_no - 1) * 20 + seats.seat_col, 9) = 0;

-- 판매 완료 주문에는 LocalDataSeeder와 같은 규칙으로 가짜 발행 완료 티켓을 붙인다.
INSERT INTO `ticket` (
    `reservation_id`, `token_id`, `mint_tx_hash`, `mint_attempt_count`, `failure_reason`, `status`,
    `created_at`, `updated_at`
)
SELECT
    reservations.reservation_id,
    1000000000 + reservations.reservation_id,
    CONCAT('0x', LPAD(LOWER(HEX(reservations.reservation_id)), 64, '0')),
    1,
    NULL,
    'OWNED',
    CURRENT_TIMESTAMP(6),
    CURRENT_TIMESTAMP(6)
FROM `reservation` AS reservations
WHERE reservations.concert_id IN (@demo_concert_roy_id, @demo_concert_mars_id);

-- 13번째 자리 중 9번째 자리와 겹치지 않는 곳을 하루 동안 선점한다.
-- 각 공연에서 14석 x 5구역 = 70석이며 회원 seed111~seed180이 사용된다.
INSERT INTO `seat_hold` (
    `concert_id`, `seat_id`, `member_id`, `expires_at`, `released_at`, `status`, `created_at`, `updated_at`
)
SELECT
    concerts.concert_id,
    seats.seat_id,
    members.member_id,
    DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL 1 DAY),
    NULL,
    'HELD',
    CURRENT_TIMESTAMP(6),
    CURRENT_TIMESTAMP(6)
FROM (
    SELECT @demo_concert_roy_id AS concert_id
    UNION ALL SELECT @demo_concert_mars_id
) AS concerts
CROSS JOIN (
    SELECT @demo_section_a_id AS section_id, 0 AS section_index
    UNION ALL SELECT @demo_section_b_id, 1
    UNION ALL SELECT @demo_section_c_id, 2
    UNION ALL SELECT @demo_section_d_id, 3
    UNION ALL SELECT @demo_section_e_id, 4
) AS sections
JOIN `seat` AS seats ON seats.section_id = sections.section_id
JOIN `member` AS members
  ON members.phone_number = CONCAT(
      '0109900',
      LPAD(
          110 + sections.section_index * 14
              + FLOOR(((seats.seat_no - 1) * 20 + seats.seat_col) / 13)
              - IF(((seats.seat_no - 1) * 20 + seats.seat_col) > 117, 1, 0),
          4,
          '0'
      )
  )
WHERE MOD((seats.seat_no - 1) * 20 + seats.seat_col, 13) = 0
  AND MOD((seats.seat_no - 1) * 20 + seats.seat_col, 9) <> 0;

DROP TEMPORARY TABLE `demo_seed_number`;


