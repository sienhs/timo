-- 현재 JPA 엔티티 기준의 빈 스키마 초기화 파일이다.
-- 보조 인덱스, UNIQUE 제약, FOREIGN KEY는 의도적으로 만들지 않는다.
-- PK는 각 엔티티 식별자 및 AUTO_INCREMENT 생성을 위해서만 둔다.
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
    PRIMARY KEY (`member_id`)
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
    PRIMARY KEY (`section_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `seat` (
    `seat_id` BIGINT NOT NULL AUTO_INCREMENT,
    `seat_no` INT NOT NULL,
    `seat_col` INT NOT NULL,
    `status` VARCHAR(255) NOT NULL,
    `section_id` BIGINT NOT NULL,
    `held_by_member_id` BIGINT NULL,
    `held_until` DATETIME(6) NULL,
    `created_at` DATETIME(6) NOT NULL,
    `updated_at` DATETIME(6) NOT NULL,
    PRIMARY KEY (`seat_id`)
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
    PRIMARY KEY (`member_id`)
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
    PRIMARY KEY (`refresh_token_id`)
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
    `seat_no`, `seat_col`, `status`, `section_id`, `held_by_member_id`, `held_until`, `created_at`, `updated_at`
)
SELECT
    FLOOR(numbers.n / 50) + 1,
    MOD(numbers.n, 50) + 1,
    'AVAILABLE',
    @load_test_section_id,
    NULL,
    NULL,
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


