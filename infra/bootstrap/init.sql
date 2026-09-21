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

-- 앱 설치본별 FCM 토큰. 토큰은 재설치·복원 시 바뀔 수 있어 회원과 분리해 둔다.
CREATE TABLE IF NOT EXISTS `push_device` (
    `push_device_id` BIGINT NOT NULL AUTO_INCREMENT,
    `member_id` BIGINT NOT NULL,
    `token` VARCHAR(512) NOT NULL,
    `platform` VARCHAR(20) NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`push_device_id`),
    UNIQUE KEY `uk_push_device_token` (`token`),
    KEY `idx_push_device_member` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 푸시 발송 결과와 관계없이 회원이 확인할 수 있는 알림함. 같은 업무 이벤트가
-- 재시도되어도 회원별 dedup_key가 한 건으로 수렴한다.
CREATE TABLE IF NOT EXISTS `notification` (
    `notification_id` BIGINT NOT NULL AUTO_INCREMENT,
    `member_id` BIGINT NOT NULL,
    `type` VARCHAR(40) NOT NULL,
    `body` VARCHAR(500) NOT NULL,
    `link_type` VARCHAR(20) NULL,
    `link_id` BIGINT NULL,
    `dedup_key` VARCHAR(120) NOT NULL,
    `read_at` DATETIME(6) NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`notification_id`),
    UNIQUE KEY `uk_notification_dedup` (`member_id`, `dedup_key`),
    KEY `idx_notification_member` (`member_id`, `notification_id` DESC),
    KEY `idx_notification_unread` (`member_id`, `read_at`),
    KEY `idx_notification_created` (`created_at`)
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
    `owner_member_id` BIGINT NOT NULL,
    `acquired_by` VARCHAR(20) NOT NULL,
    `acquired_at` DATETIME(6) NOT NULL,
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
    `seat_release_at` DATETIME(6) NULL,
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

-- 입장 완료 티켓으로 만든 개인 소장품. 원본·합성 이미지 파일은 S3에, 그 key와 앱 렌더링
-- 메타데이터만 RDS에 둔다. ticket 및 (member, client_goods_id) 유니크 제약이 동시 요청과
-- 클라이언트 재시도를 각각 한 건으로 수렴시킨다.
-- 굿즈 제작 중 올라간 이미지의 수명주기 대장. 굿즈에 연결되지 않은 업로드는 청소 배치가
-- status 및 created_at 인덱스로 찾아 스토리지와 함께 정리한다.
CREATE TABLE IF NOT EXISTS `goods_upload` (
    `goods_upload_id` BIGINT NOT NULL AUTO_INCREMENT,
    `member_id`       BIGINT NOT NULL,
    `ticket_id`       BIGINT NOT NULL,
    `image_key`       VARCHAR(512) NOT NULL,
    `status`          VARCHAR(20) NOT NULL,
    `created_at`      DATETIME(6) NOT NULL,
    `updated_at`      DATETIME(6) NOT NULL,
    `deleted_at`      DATETIME(6) NULL,
    PRIMARY KEY (`goods_upload_id`),
    UNIQUE KEY `uk_goods_upload_image_key` (`image_key`),
    KEY `idx_goods_upload_status_created` (`status`, `created_at`),
    KEY `idx_goods_upload_ticket` (`ticket_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `goods` (
    `goods_id` BIGINT NOT NULL AUTO_INCREMENT,
    `ticket_id` BIGINT NOT NULL,
    `member_id` BIGINT NOT NULL,
    `concert_id` BIGINT NOT NULL,
    `client_goods_id` VARCHAR(64) NOT NULL,
    `background_key` VARCHAR(512) NOT NULL,
    `source_background_key` VARCHAR(512) NULL,
    `person_composite_key` VARCHAR(512) NULL,
    `depth_map_key` VARCHAR(512) NULL,
    `preview_key` VARCHAR(512) NULL,
    `effect_type` VARCHAR(20) NOT NULL,
    `background_framing` JSON NULL,
    `person_layers` JSON NOT NULL,
    `transition_config` JSON NOT NULL,
    `render_metadata` JSON NOT NULL,
    `concert_snapshot` JSON NOT NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`goods_id`),
    UNIQUE KEY `uk_goods_ticket` (`ticket_id`),
    UNIQUE KEY `uk_goods_member_client` (`member_id`, `client_goods_id`),
    KEY `idx_goods_member_created` (`member_id`, `created_at`)
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

-- 초기 bootstrap에 없던 컬럼·엔티티 유니크 제약을 기존 운영 테이블에도 맞춘다. MySQL은
-- ALTER TABLE ADD COLUMN/UNIQUE KEY에 IF NOT EXISTS를 지원하지 않으므로 메타데이터를 확인한
-- 뒤에만 실행한다. 각 제약을 추가하기 전 운영 데이터의 중복 여부는 배포 점검에서 확인한다.
DELIMITER //
CREATE PROCEDURE ensure_entity_unique_constraints()
BEGIN
    -- Ticket.ownerMemberId는 QR·굿즈·내 티켓·양도·알림의 현재 소유권 기준이다.
    -- 이미 운영 중인 티켓은 원 예매자를 BOOKING 취득자로 보정한 뒤 NOT NULL로 바꾼다.
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'ticket'
          AND column_name = 'owner_member_id'
    ) THEN
        ALTER TABLE `ticket`
            ADD COLUMN `owner_member_id` BIGINT NULL AFTER `reservation_id`;
        UPDATE `ticket` t
        JOIN `reservation` r ON r.`reservation_id` = t.`reservation_id`
           SET t.`owner_member_id` = r.`member_id`
         WHERE t.`owner_member_id` IS NULL;
        ALTER TABLE `ticket`
            MODIFY COLUMN `owner_member_id` BIGINT NOT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'ticket'
          AND column_name = 'acquired_by'
    ) THEN
        ALTER TABLE `ticket`
            ADD COLUMN `acquired_by` VARCHAR(20) NULL AFTER `owner_member_id`;
        UPDATE `ticket`
           SET `acquired_by` = 'BOOKING'
         WHERE `acquired_by` IS NULL;
        ALTER TABLE `ticket`
            MODIFY COLUMN `acquired_by` VARCHAR(20) NOT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'ticket'
          AND column_name = 'acquired_at'
    ) THEN
        ALTER TABLE `ticket`
            ADD COLUMN `acquired_at` DATETIME(6) NULL AFTER `acquired_by`;
        UPDATE `ticket` t
        JOIN `reservation` r ON r.`reservation_id` = t.`reservation_id`
           SET t.`acquired_at` = r.`created_at`
         WHERE t.`acquired_at` IS NULL;
        ALTER TABLE `ticket`
            MODIFY COLUMN `acquired_at` DATETIME(6) NOT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'reservation'
          AND column_name = 'seat_release_at'
    ) THEN
        ALTER TABLE `reservation`
            ADD COLUMN `seat_release_at` DATETIME(6) NULL AFTER `cancelled_at`;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE() AND table_name = 'wallet'
          AND index_name = 'uk_wallet_address'
    ) THEN
        ALTER TABLE `wallet` ADD UNIQUE KEY `uk_wallet_address` (`address`);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE() AND table_name = 'venue'
          AND index_name = 'uk_venue_name'
    ) THEN
        ALTER TABLE `venue` ADD UNIQUE KEY `uk_venue_name` (`venue_name`);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE() AND table_name = 'concert_artist'
          AND index_name = 'uk_concert_artist'
    ) THEN
        ALTER TABLE `concert_artist`
            ADD UNIQUE KEY `uk_concert_artist` (`concert_id`, `artist_id`);
    END IF;
END //
DELIMITER ;
CALL ensure_entity_unique_constraints();
DROP PROCEDURE ensure_entity_unique_constraints;

-- 즉시 좌석 선점 부하 테스트를 할 수 있는 단일 공연장·공연·구역·좌석 1,000석.
