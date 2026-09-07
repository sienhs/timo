-- 테스트용 스키마.
-- timo_test 는 기본값(단독 작업용), _a ~ _d 는 worktree 병렬 작업용이다.
-- ddl-auto: create-drop 이라 스키마를 공유하면 동시 실행 시 서로를 drop 한다.

CREATE DATABASE IF NOT EXISTS `timo_test`   CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `timo_test_a` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `timo_test_b` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `timo_test_c` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `timo_test_d` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON `timo_test`.*   TO 'timo'@'%';
GRANT ALL PRIVILEGES ON `timo_test_a`.* TO 'timo'@'%';
GRANT ALL PRIVILEGES ON `timo_test_b`.* TO 'timo'@'%';
GRANT ALL PRIVILEGES ON `timo_test_c`.* TO 'timo'@'%';
GRANT ALL PRIVILEGES ON `timo_test_d`.* TO 'timo'@'%';

FLUSH PRIVILEGES;
