-- 현재 JPA 엔티티 기준의 운영 RDS 스키마 초기화 파일이다.
-- 모든 DDL은 재실행 가능하다. 이미 존재하는 테이블·운영 데이터는 삭제하거나 시드하지 않는다.
-- JPA 엔티티가 선언한 UNIQUE 제약과 조회 경로의 보조 인덱스는 함께 만든다.
-- FOREIGN KEY는 애플리케이션의 기존 참조 방식에 맞춰 만들지 않는다.

CREATE TABLE IF NOT EXISTS `member` (
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

-- 회원별 공연 찜. 같은 회원이 같은 공연을 중복해서 찜하지 못하게 한다.
CREATE TABLE IF NOT EXISTS `concert_wish` (
    `wish_id` BIGINT NOT NULL AUTO_INCREMENT,
    `member_id` BIGINT NOT NULL,
    `concert_id` BIGINT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`wish_id`),
    UNIQUE KEY `uk_wish_member_concert` (`member_id`, `concert_id`),
    KEY `idx_wish_concert` (`concert_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 취소표 구매 기회. OFFERED 상태의 동일 공연·좌석은 한 건만 열릴 수 있다.
CREATE TABLE IF NOT EXISTS `cancel_offer` (
    `offer_id` BIGINT NOT NULL AUTO_INCREMENT,
    `concert_id` BIGINT NOT NULL,
    `seat_id` BIGINT NOT NULL,
    `member_id` BIGINT NOT NULL,
    `source_reservation_id` BIGINT NOT NULL,
    `expires_at` DATETIME(6) NOT NULL,
    `status` VARCHAR(20) NOT NULL,
    `reservation_id` BIGINT NULL,
    `active_seat` BIGINT GENERATED ALWAYS AS (IF(`status` = 'OFFERED', `seat_id`, NULL)) STORED,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`offer_id`),
    UNIQUE KEY `uk_offer_seat_active` (`concert_id`, `active_seat`),
    KEY `idx_offer_member_status` (`member_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `venue` (
    `venue_id` BIGINT NOT NULL AUTO_INCREMENT,
    `venue_name` VARCHAR(10) NULL,
    `venue_address` VARCHAR(255) NULL,
    `total_seat_count` INT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`venue_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `artist` (
    `artist_id` BIGINT NOT NULL AUTO_INCREMENT,
    `artist_name` VARCHAR(200) NULL,
    `profile_image` TEXT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`artist_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `concert` (
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

CREATE TABLE IF NOT EXISTS `section` (
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

CREATE TABLE IF NOT EXISTS `seat` (
    `seat_id` BIGINT NOT NULL AUTO_INCREMENT,
    `seat_no` INT NOT NULL,
    `seat_col` INT NOT NULL,
    `section_id` BIGINT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`seat_id`),
    UNIQUE KEY `uk_seat_section_position` (`section_id`, `seat_no`, `seat_col`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `concert_artist` (
    `concert_artist_id` BIGINT NOT NULL AUTO_INCREMENT,
    `concert_id` BIGINT NOT NULL,
    `artist_id` BIGINT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`concert_artist_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `concert_image` (
    `concert_image_id` BIGINT NOT NULL AUTO_INCREMENT,
    `concert_id` BIGINT NOT NULL,
    `image_key` VARCHAR(500) NOT NULL,
    `sort_order` INT NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`concert_image_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `login_info` (
    `member_id` BIGINT NOT NULL,
    `username` VARCHAR(50) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`member_id`),
    UNIQUE KEY `uk_login_info_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `wallet` (
    `member_id` BIGINT NOT NULL,
    `address` VARCHAR(42) NOT NULL,
    `encrypted_keystore_json` TEXT NOT NULL,
    `wrapped_dek` VARCHAR(255) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `refresh_token` (
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
CREATE TABLE IF NOT EXISTS `ticket` (
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
CREATE TABLE IF NOT EXISTS `wallet_transaction` (
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
CREATE TABLE IF NOT EXISTS `seat_hold` (
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
CREATE TABLE IF NOT EXISTS `reservation` (
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
CREATE TABLE IF NOT EXISTS `ticket_listing` (
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
CREATE TABLE IF NOT EXISTS `ticket_trade` (
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
