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
    `price` INT NOT NULL,
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


