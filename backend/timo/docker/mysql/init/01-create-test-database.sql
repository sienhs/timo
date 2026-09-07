CREATE DATABASE IF NOT EXISTS `timo_test`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON `timo_test`.* TO 'timo'@'%';

FLUSH PRIVILEGES;
