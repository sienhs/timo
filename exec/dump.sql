/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.5.29-MariaDB, for Linux (x86_64)
--
-- Host: ticketing-dev-mysql.chkgu8caousd.ap-northeast-2.rds.amazonaws.com    Database: ticketing
-- ------------------------------------------------------
-- Server version	8.4.9

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `artist`
--

DROP TABLE IF EXISTS `artist`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `artist` (
  `artist_id` bigint NOT NULL AUTO_INCREMENT,
  `artist_name` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `profile_image` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`artist_id`)
) ENGINE=InnoDB AUTO_INCREMENT=159 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `artist`
--

LOCK TABLES `artist` WRITE;
/*!40000 ALTER TABLE `artist` DISABLE KEYS */;
INSERT INTO `artist` VALUES (1,'KEY','artist/artist_key.png','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(2,'TAKUYA KIMURA','artist/artist_takuya_kimura.jpg','2026-09-23 07:24:13.816467','2026-09-23 10:38:28.157761'),(3,'김장훈','artist/artist_gimjanghun.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(4,'김광진','artist/artist_gimgwangjin.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(5,'볼빨간사춘기','artist/artist_bolppalgansachungi.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(6,'산다라박','artist/artist_sandarabak.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(7,'선우정아','artist/artist_seonujeonga.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(8,'소수빈','artist/artist_sosubin.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(9,'홍이삭','artist/artist_hongisak.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(10,'송소희','artist/artist_songsohui.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(11,'추다혜','artist/artist_chudahye.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(12,'앙상블 시나위','artist/artist_angsangbeul_sinawi.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(13,'LEO MUSE','artist/artist_leo_muse.png','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(14,'홍경민','artist/artist_honggyeongmin.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(15,'산들','artist/artist_sandeul.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(16,'＆TEAM','artist/artist_andteam.jpg','2026-09-23 07:24:13.816467','2026-09-23 10:27:20.477130'),(17,'레이니','artist/artist_reini.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(18,'조관우','artist/artist_jogwanu.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(19,'PENTAGON','artist/artist_pentagon.jpg','2026-09-23 07:24:13.816467','2026-09-23 10:38:28.157761'),(20,'찰리 푸스','artist/artist_chalri_puseu.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(21,'장윤정','artist/artist_jangyunjeong.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(22,'김동률','artist/artist_kimdongrule.jpg','2026-09-23 07:24:13.816467','2026-09-23 10:27:20.477130'),(23,'ILLIT','artist/artist_illit.png','2026-09-23 07:24:13.816467','2026-09-23 10:38:28.157761'),(24,'NEXZ','artist/artist_nexz.jpg','2026-09-23 07:24:13.816467','2026-09-23 10:38:28.157761'),(25,'ano','artist/artist_ano.jpg','2026-09-23 07:24:13.816467','2026-09-23 10:38:28.157761'),(26,'이승기','artist/artist_iseunggi.png','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(27,'조슈아 레드먼 쿼텟','artist/artist_redmun.jpg','2026-09-23 07:24:13.816467','2026-09-23 10:27:20.477130'),(28,'다이나믹 듀오','artist/artist_dainamik_dyuo.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(29,'Minos (마이노스)','artist/artist_minos_mainoseu.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(30,'허클베리피','artist/artist_heokeulberipi.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(31,'범키','artist/artist_beomki.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(32,'한해','artist/artist_hanhae.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(33,'치타','artist/artist_chita.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(34,'그리','artist/artist_geuri.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(35,'슬리피','artist/artist_seulripi.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(36,'김수희','artist/artist_gimsuhui.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(37,'심규선','artist/artist_simgyuseon.png','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(38,'벤슨 분','artist/artist_benson.jpg','2026-09-23 07:24:13.816467','2026-09-23 10:27:20.477130'),(39,'키퍼','artist/artist_kipeo.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(40,'김재환','artist/artist_gimjaehwan.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(47,'Morgenshtern Alisher','artist/artist_morgenshtern_alisher.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(48,'윤종신','artist/artist_yunjongsin.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(50,'최유리','artist/artist_choeyuri.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(52,'로이킴','artist/artist_roikim.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(59,'KWON JIN AH','artist/artist_kwon_jin_ah.png','2026-09-23 07:24:13.816467','2026-09-23 10:38:28.157761'),(61,'카즈미 타테이시','artist/artist_kajeumi_tateisi.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(62,'시노부 사토','artist/artist_sinobu_sato.gif','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(64,'브루노 마스','artist/artist_beuruno_maseu.jpg','2026-09-23 07:24:13.816467','2026-09-23 07:24:13.816467'),(128,'Nujabes Metaphorical Ensemble',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(129,'이창민','artist/artist_ichangmin.jpg','2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(130,'코이키즈(KO1KEYZ)',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(131,'남진',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(132,'까치산',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(133,'이은미',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(134,'김필',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(135,'제시 골드',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(136,'LET ME KNOW',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(137,'Sunny Day Service',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(138,'YUURI',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(139,'카키',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(140,'칼리드','artist/artist_kalrideu.jpg','2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(141,'FKJ',NULL,'2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(142,'마오 스즈키','artist/artist_mao_seujeuki.gif','2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191'),(143,'마룬5','artist/artist_marun5.jpg','2026-09-23 18:15:18.594191','2026-09-23 18:15:18.594191');
/*!40000 ALTER TABLE `artist` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cancel_offer`
--

DROP TABLE IF EXISTS `cancel_offer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cancel_offer` (
  `offer_id` bigint NOT NULL AUTO_INCREMENT,
  `concert_id` bigint NOT NULL,
  `seat_id` bigint NOT NULL,
  `member_id` bigint NOT NULL,
  `source_reservation_id` bigint NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `reservation_id` bigint DEFAULT NULL,
  `active_seat` bigint GENERATED ALWAYS AS (if((`status` = _utf8mb4'OFFERED'),`seat_id`,NULL)) STORED,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`offer_id`),
  UNIQUE KEY `uk_offer_seat_active` (`concert_id`,`active_seat`),
  KEY `idx_offer_member_status` (`member_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cancel_offer`
--

LOCK TABLES `cancel_offer` WRITE;
/*!40000 ALTER TABLE `cancel_offer` DISABLE KEYS */;
/*!40000 ALTER TABLE `cancel_offer` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `concert`
--

DROP TABLE IF EXISTS `concert`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `concert` (
  `concert_id` bigint NOT NULL AUTO_INCREMENT,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `genre` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `poster_image_key` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `age_rating` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `view_count` int NOT NULL,
  `start_date` datetime(6) DEFAULT NULL,
  `end_date` datetime(6) DEFAULT NULL,
  `open_at` datetime(6) DEFAULT NULL,
  `venue_id` bigint NOT NULL,
  `organizer_id` bigint DEFAULT NULL,
  `face_price` decimal(38,0) DEFAULT NULL,
  `show_id` decimal(38,0) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`concert_id`)
) ENGINE=InnoDB AUTO_INCREMENT=95 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `concert`
--

LOCK TABLES `concert` WRITE;
/*!40000 ALTER TABLE `concert` DISABLE KEYS */;
INSERT INTO `concert` VALUES (1,'2026 KEY B-day PARTY ［KEYdult Club］','CONCERT','poster/poster_main_key_b_day_party_keydult_club.gif','2026 KEY B-day PARTY ［KEYdult Club］','AGE_7','CLOSED',0,'2026-09-23 16:00:00.000000','2026-09-23 18:00:00.000000','2026-09-09 19:00:00.000000',1,1,NULL,1,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.165235'),(2,'TAKUYA KIMURA Live Tour 2026 Checkpoint in Seoul','CONCERT','poster/poster_main_takuya_kimura_2026_checkpoint_seoul.gif','TAKUYA KIMURA Live Tour 2026 Checkpoint in Seoul','AGE_7','CLOSED',0,'2026-09-15 19:00:00.000000','2026-09-15 21:00:00.000000','2026-06-29 19:00:00.000000',1,1,NULL,2,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.219461'),(3,'2026 김장훈 전국투어 콘서트 : 원맨쇼 - 제주','CONCERT','poster/poster_main_gimjanghun_wonmaensyo_jeju.gif','2026 김장훈 전국투어 콘서트 : 원맨쇼 - 제주','AGE_7','CLOSED',0,'2026-09-16 18:00:00.000000','2026-09-16 20:00:00.000000','2026-06-19 09:00:00.000000',1,1,NULL,3,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.270454'),(4,'충주 파크뮤직페스티벌 WITH GUGAK','CONCERT','poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif','충주 파크뮤직페스티벌 WITH GUGAK','AGE_7','ON_SALE',0,'2026-10-03 13:30:00.000000','2026-10-03 21:30:00.000000','2026-08-28 14:00:00.000000',1,1,NULL,4,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.324309'),(5,'2026 LEO MUSE FANMEETING ［TAKE 운－PLAY LEO］','CONCERT','poster/poster_main_leo_muse_fanmeeting_take_un_play_leo.gif','2026 LEO MUSE FANMEETING ［TAKE 운－PLAY LEO］','AGE_7','ON_SALE',0,'2026-10-03 14:00:00.000000','2026-10-03 15:40:00.000000','2026-09-07 19:00:00.000000',1,1,NULL,5,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.425576'),(6,'홍경민 콘서트-10월의 매달리스트 콘서트','CONCERT','poster/poster_main_honggyeongmin_10wolui_maedalriseuteu.gif','그 때의 나로 돌아갑니다.','AGE_7','ON_SALE',0,'2026-10-03 15:00:00.000000','2026-10-03 17:30:00.000000','2026-09-07 12:00:00.000000',1,1,NULL,6,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.483149'),(7,'2026 산들 단독 콘서트 〈바람결〉','CONCERT','poster/poster_main_sandeul_baramgyeol.gif','2026 산들 단독 콘서트 〈바람결〉','AGE_7','ON_SALE',0,'2026-10-03 18:00:00.000000','2026-10-03 20:00:00.000000','2026-09-08 20:00:00.000000',1,1,NULL,7,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.544266'),(8,'2026 ＆TEAM CONCERT TOUR ‘BLAZE THE WAY’ ENCORE in KSPO DOME','CONCERT','poster/poster_main_team_blaze_way_encore_kspo_dome.gif','2026 ＆TEAM CONCERT TOUR ‘BLAZE THE WAY’ ENCORE in KSPO DOME','AGE_7','ON_SALE',0,'2026-10-03 18:00:00.000000','2026-10-03 20:00:00.000000','2026-08-11 20:00:00.000000',1,1,NULL,8,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.580909'),(9,'레이니 내한공연','CONCERT','poster/poster_main_reini.gif','LANY: soft world tour in Korea','AGE_12','CLOSED',0,'2026-09-17 19:00:00.000000','2026-09-17 21:00:00.000000','2026-03-31 12:00:00.000000',1,1,NULL,9,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.610372'),(10,'2026 조관우 MUSIC 콘서트 - 가을의 기적(부천)','CONCERT','poster/poster_main_jogwanu_music_gaeului_gijeok_bucheon.gif','2026 조관우 MUSIC 콘서트 - 가을의 기적(부천)','AGE_7','ON_SALE',0,'2026-10-04 17:00:00.000000','2026-10-04 19:30:00.000000','2026-08-27 14:00:00.000000',1,1,NULL,10,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.651136'),(11,'PENTAGON 10th Anniversary Tour 〈101010〉 in Seoul','CONCERT','poster/poster_main_pentagon_10th_anniversary_101010_seoul.gif','PENTAGON 10th Anniversary Tour 〈101010〉 in Seoul','AGE_7','ON_SALE',0,'2026-10-09 19:00:00.000000','2026-10-09 20:40:00.000000','2026-09-08 20:00:00.000000',1,1,NULL,11,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.692544'),(12,'찰리 푸스 내한공연','CONCERT','poster/poster_main_chalri_puseu.gif','Charlie Puth - Whatever’s Clever! World Tour in Seoul','AGE_12','ON_SALE',0,'2026-10-11 19:00:00.000000','2026-10-11 21:00:00.000000','2026-04-29 12:00:00.000000',1,1,NULL,12,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.732306'),(13,'［부산］ 2026 장윤정 라이브 콘서트 〈THE MASTER〉','CONCERT','poster/poster_main_busan_2026_jangyunjeong_master.gif','［부산］ 2026 장윤정 라이브 콘서트 〈THE MASTER〉','AGE_7','ON_SALE',0,'2026-10-17 14:00:00.000000','2026-10-17 16:00:00.000000','2026-08-06 15:00:00.000000',1,1,NULL,13,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.770144'),(14,'2026 김동률 콘서트 ‘오래된 노래’','CONCERT','poster/poster_main_gimdongryul_oraedoen_norae.gif','2026 김동률 콘서트 ‘오래된 노래’','AGE_7','ON_SALE',0,'2026-10-17 17:00:00.000000','2026-10-17 19:30:00.000000','2026-09-04 17:00:00.000000',1,1,NULL,14,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.810591'),(15,'ILLIT LIVE ‘PRESS START♥’ ENCORE in KOREA','CONCERT','poster/poster_main_illit_press_start_encore_korea.gif','ILLIT LIVE ‘PRESS START♥’ ENCORE in KOREA','AGE_7','ON_SALE',0,'2026-10-17 18:00:00.000000','2026-10-17 20:00:00.000000','2026-09-17 20:00:00.000000',1,1,NULL,15,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.841631'),(16,'NEXZ 1ST ASIA TOUR 〈SAUCIN’ THE WORLD〉','CONCERT','poster/poster_main_nexz_1st_asia_saucin_world.gif','NEXZ 1ST ASIA TOUR 〈SAUCIN’ THE WORLD〉','AGE_7','ON_SALE',0,'2026-10-17 18:00:00.000000','2026-10-17 20:00:00.000000','2026-09-16 20:00:00.000000',1,1,NULL,16,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.873019'),(17,'ano LIVE in SEOUL, KOREA 2026','CONCERT','poster/poster_main_ano_seoul_korea_2026.gif','ano LIVE in SEOUL, KOREA 2026','AGE_7','ON_SALE',0,'2026-10-17 18:00:00.000000','2026-10-17 19:30:00.000000','2026-07-21 20:00:00.000000',1,1,NULL,17,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.903564'),(18,'2026 이승기 콘서트 〈기승전 : 樂〉','CONCERT','poster/poster_main_iseunggi_giseungjeon.gif','2026 이승기 콘서트 〈기승전 : 樂〉','AGE_7','ON_SALE',0,'2026-10-23 18:00:00.000000','2026-10-23 20:00:00.000000','2026-09-11 18:00:00.000000',1,1,NULL,18,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.934279'),(19,'조슈아 레드먼 쿼텟 내한공연','CONCERT','poster/poster_main_josyua_redeumeon_kwotet.gif','Words Fall Short','AGE_7','ON_SALE',0,'2026-10-23 19:30:00.000000','2026-10-23 21:00:00.000000','2026-06-25 10:00:00.000000',1,1,NULL,19,'2026-09-23 07:24:14.068781','2026-09-23 16:24:39.971500'),(20,'강원 RED FRYS 2026 - 정규티켓','CONCERT','poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif','강원 RED FRYS 2026 - 정규티켓','ALL','ON_SALE',0,'2026-10-24 15:30:00.000000','2026-10-24 22:00:00.000000','2026-08-31 14:00:00.000000',1,1,NULL,20,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.001338'),(21,'2026 김수희 전국투어 콘서트 : 우리 다시, 김수희 - 광양','CONCERT','poster/poster_main_gimsuhui_uri_dasi_gimsuhui_gwangyang.gif','2026 김수희 전국투어 콘서트 : 우리 다시, 김수희 - 광양','AGE_7','ON_SALE',0,'2026-10-24 18:00:00.000000','2026-10-24 20:00:00.000000','2026-08-27 11:00:00.000000',1,1,NULL,21,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.042489'),(22,'2026 심규선 단독 콘서트［SANCTUARY］','CONCERT','poster/poster_main_simgyuseon_sanctuary.gif','2026 심규선 단독 콘서트［SANCTUARY］','AGE_7','ON_SALE',0,'2026-10-24 18:00:00.000000','2026-10-24 20:30:00.000000','2026-09-09 20:00:00.000000',1,1,NULL,22,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.075423'),(23,'벤슨 분 내한공연','CONCERT','poster/poster_main_benseun_bun.gif','Benson Boone: Wanted Man Tour in Seoul','ALL','ON_SALE',0,'2026-10-26 20:00:00.000000','2026-10-26 22:00:00.000000','2026-07-21 12:00:00.000000',1,1,NULL,23,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.109416'),(24,'키퍼 (Kiefer) 내한공연','CONCERT','poster/poster_main_kipeo_kiefer.gif','Kiefer - Live in Seoul','ALL','ON_SALE',0,'2026-10-28 20:00:00.000000','2026-10-28 22:00:00.000000','2026-09-04 12:00:00.000000',1,1,NULL,24,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.137953'),(25,'2026 김재환 콘서트 ［여백:餘白］','CONCERT','poster/poster_main_gimjaehwan_yeobaek.gif','2026 김재환 콘서트 ［여백:餘白］','AGE_7','ON_SALE',0,'2026-10-31 18:00:00.000000','2026-10-31 20:00:00.000000','2026-09-09 20:00:00.000000',1,1,NULL,25,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.173137'),(32,'Morgenshtern Alisher World Tour Part 2 Seoul','CONCERT','poster/poster_main_morgenshtern_alisher_world_part_2_seoul.gif','Morgenshtern Alisher World Tour Part 2 Seoul','AGE_19','ON_SALE',0,'2026-11-11 20:00:00.000000','2026-11-11 22:00:00.000000','2026-07-16 12:00:00.000000',1,1,NULL,31,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.380390'),(33,'2026 윤종신 전국투어 콘서트 〈가을냄새〉 - 대전','CONCERT','poster/poster_main_yunjongsin_gaeulnaemsae_daejeon.gif','2026 윤종신 전국투어 콘서트 〈가을냄새〉 - 대전','AGE_7','ON_SALE',0,'2026-11-14 17:00:00.000000','2026-11-14 19:00:00.000000','2026-09-09 14:00:00.000000',1,1,NULL,32,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.412991'),(35,'［대구］ 최유리 콘서트 2026 : 머무름','CONCERT','poster/poster_main_daegu_choeyuri_2026_meomureum.gif','［대구］ 최유리 콘서트 2026 : 머무름','AGE_7','ON_SALE',0,'2026-11-14 18:00:00.000000','2026-11-14 20:00:00.000000','2026-09-01 20:00:00.000000',1,1,NULL,34,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.482189'),(37,'2026-27 로이킴 LIVE TOUR ［R:O:Y］ in SEOUL','CONCERT','poster/poster_main_roikim_r_o_y_seoul.gif','2026-27 로이킴 LIVE TOUR ［R:O:Y］ in SEOUL','AGE_7','ON_SALE',0,'2026-11-21 18:00:00.000000','2026-11-21 20:00:00.000000','2026-09-17 20:00:00.000000',1,1,NULL,36,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.584690'),(44,'2026 KWON JIN AH LIVE TOUR ‘THIS WINTER’ IN DAEGU','CONCERT','poster/poster_main_kwon_jin_ah_this_winter_daegu.gif','2026 KWON JIN AH LIVE TOUR ‘THIS WINTER’ IN DAEGU','AGE_7','SCHEDULED',0,'2026-12-12 18:00:00.000000','2026-12-12 20:00:00.000000','2026-09-23 17:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 07:24:14.068781','2026-09-23 07:24:14.068781'),(45,'2026 다이나믹 듀오 단독 콘서트 “가끔씩 오래 보자” - 부산','CONCERT','poster/poster_main_dainamik_dyuo_gakkeumssik_orae_boja_busan.gif','2026 다이나믹 듀오 단독 콘서트 “가끔씩 오래 보자” - 부산','AGE_7','SCHEDULED',0,'2026-12-12 18:00:00.000000','2026-12-12 20:00:00.000000','2026-09-30 19:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 07:24:14.068781','2026-09-23 07:24:14.068781'),(48,'브루노 마스 내한공연','CONCERT','poster/poster_main_beuruno_maseu.gif','Bruno Mars - The Romantic Tour','AGE_7','ON_SALE',0,'2027-05-21 19:45:00.000000','2027-05-21 21:45:00.000000','2026-09-16 12:00:00.000000',1,1,NULL,45,'2026-09-23 07:24:14.068781','2026-09-23 16:24:40.899360'),(64,'Nujabes Metaphorical Ensemble Live in Seoul','CONCERT','poster/poster_main_nujabes_metaphorical_ensemble_seoul.gif','누자베스 메타포리컬 앙상블','ALL','ON_SALE',0,'2026-10-31 18:00:00.000000','2026-10-31 19:40:00.000000','2026-09-03 12:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(65,'2026 이창민 팬미팅 〈PURPLE LOUNGE〉','CONCERT','poster/poster_main_ichangmin_paenmiting_purple_lounge.gif','2026 이창민 팬미팅 〈PURPLE LOUNGE〉','AGE_7','ON_SALE',0,'2026-11-01 18:00:00.000000','2026-11-01 19:30:00.000000','2026-09-18 18:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(66,'2026 KO1KEYZ 1ST FAN MEETING IN SEOUL','CONCERT','poster/poster_main_ko1keyz_1st_fan_meeting_seoul.gif','2026 KO1KEYZ 1ST FAN MEETING IN SEOUL','AGE_7','ON_SALE',0,'2026-11-07 14:00:00.000000','2026-11-07 16:00:00.000000','2026-09-18 18:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(67,'［데뷔 60주년 기념공연］ 2026 남진 전국투어 콘서트 - 익산','CONCERT','poster/poster_main_debwi_60junyeon_ginyeom_2026_namjin_iksan.gif','［데뷔 60주년 기념공연］ 2026 남진 전국투어 콘서트 - 익산','AGE_7','ON_SALE',0,'2026-11-07 17:00:00.000000','2026-11-07 19:00:00.000000','2026-08-21 11:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(68,'2026 까치산투어 〈여기,까치산입니다.〉 - 대전','CONCERT','poster/poster_main_kkachisan_yeogi_kkachisanipnida_daejeon.gif','2026 까치산투어 〈여기,까치산입니다.〉 - 대전','AGE_7','SCHEDULED',0,'2026-11-07 19:00:00.000000','2026-11-07 20:30:00.000000','2026-09-22 19:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(69,'이은미 콘서트 with 오케스트라 : 추억이 핀다 - 청주','CONCERT','poster/poster_main_ieunmi_okeseuteura_chueoki_pinda_cheongju.gif','이은미 콘서트 with 오케스트라 : 추억이 핀다 - 청주','AGE_7','ON_SALE',0,'2026-11-08 17:00:00.000000','2026-11-08 19:00:00.000000','2026-08-19 14:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(70,'2026 김필 콘서트 〈JOURNEY〉','CONCERT','poster/poster_main_gimpil_journey.gif','2026 김필 콘서트 〈JOURNEY〉','AGE_7','ON_SALE',0,'2026-11-14 18:00:00.000000','2026-11-14 20:00:00.000000','2026-09-11 19:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(71,'제시 골드 (JESSE GOLD) 내한공연','CONCERT','poster/poster_main_jesi_goldeu_jesse_gold.gif','Jesse Gold - Live in Seoul','ALL','ON_SALE',0,'2026-11-16 20:00:00.000000','2026-11-16 22:00:00.000000','2026-06-12 09:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(72,'LET ME KNOW LIVE TOUR 2026-Re: Still Romance-','CONCERT','poster/poster_main_let_me_know_2026_re_still_romance.gif','LET ME KNOW LIVE TOUR 2026-Re: Still Romance-','AGE_7','ON_SALE',0,'2026-11-28 18:00:00.000000','2026-11-28 19:10:00.000000','2026-07-31 18:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(73,'Sunny Day Service TOUR 2026 in SEOUL','CONCERT','poster/poster_main_sunny_day_service_2026_seoul.gif','APF CONCERTS PRESENTS','AGE_7','ON_SALE',0,'2026-12-03 20:00:00.000000','2026-12-03 22:30:00.000000','2026-08-13 14:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(74,'YUURI LIVE 2026 IN SEOUL','CONCERT','poster/poster_main_yuuri_2026_seoul.gif','YUURI LIVE 2026 IN SEOUL','AGE_7','ON_SALE',0,'2026-12-05 18:00:00.000000','2026-12-05 19:30:00.000000','2026-07-31 20:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(75,'카키 내한공연 (Khaki ONE-MAN Live in Seoul)','CONCERT','poster/poster_main_kaki_khaki_one_man_seoul.gif','카키 내한공연 (Khaki ONE-MAN Live in Seoul)','AGE_7','ON_SALE',0,'2026-12-05 19:00:00.000000','2026-12-05 20:30:00.000000','2026-09-16 18:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(76,'칼리드 내한공연','CONCERT','poster/poster_main_kalrideu.gif','Khalid: It\'s Always Summer Somewhere Tour in Seoul','AGE_12','ON_SALE',0,'2026-12-05 19:00:00.000000','2026-12-05 21:00:00.000000','2026-07-16 12:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(77,'FKJ 내한공연','CONCERT','poster/poster_main_fkj.gif','FKJ - Tyber Tour in Korea','AGE_12','ON_SALE',0,'2026-12-06 19:00:00.000000','2026-12-06 21:00:00.000000','2026-07-07 12:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(78,'2026 카즈미 타테이시 트리오 내한공연-지브리, 재즈를 만나다-(광주)','CONCERT','poster/poster_main_kajeumi_tateisi_teurio_jibeuri_jaejeureul_mannada_gwangju.gif','GHIBLI meets JAZZ','AGE_7','ON_SALE',0,'2026-12-19 17:00:00.000000','2026-12-19 18:40:00.000000','2026-07-30 12:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950'),(79,'마룬5 내한공연','CONCERT','poster/poster_main_marun5.gif','Maroon 5 Asia 2027 in Seoul','AGE_12','ON_SALE',0,'2027-01-27 20:00:00.000000','2027-01-27 22:00:00.000000','2026-08-14 12:00:00.000000',1,NULL,NULL,NULL,'2026-09-23 18:15:18.942950','2026-09-23 18:15:18.942950');
/*!40000 ALTER TABLE `concert` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `concert_alarm`
--

DROP TABLE IF EXISTS `concert_alarm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `concert_alarm` (
  `alarm_id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `concert_id` bigint NOT NULL,
  `alarm_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`alarm_id`),
  UNIQUE KEY `uk_alarm_member_concert_type` (`member_id`,`concert_id`,`alarm_type`),
  KEY `idx_alarm_concert_type` (`concert_id`,`alarm_type`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `concert_alarm`
--

LOCK TABLES `concert_alarm` WRITE;
/*!40000 ALTER TABLE `concert_alarm` DISABLE KEYS */;
INSERT INTO `concert_alarm` VALUES (2,2,48,'MARKET_LISTING','2026-09-23 16:54:30.055893','2026-09-23 16:54:30.055893');
/*!40000 ALTER TABLE `concert_alarm` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `concert_artist`
--

DROP TABLE IF EXISTS `concert_artist`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `concert_artist` (
  `concert_artist_id` bigint NOT NULL AUTO_INCREMENT,
  `concert_id` bigint NOT NULL,
  `artist_id` bigint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`concert_artist_id`),
  UNIQUE KEY `uk_concert_artist` (`concert_id`,`artist_id`)
) ENGINE=InnoDB AUTO_INCREMENT=159 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `concert_artist`
--

LOCK TABLES `concert_artist` WRITE;
/*!40000 ALTER TABLE `concert_artist` DISABLE KEYS */;
INSERT INTO `concert_artist` VALUES (1,1,1,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(2,2,2,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(3,3,3,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(4,4,12,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(5,4,11,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(6,4,10,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(7,4,9,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(8,4,8,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(9,4,7,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(10,4,6,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(11,4,5,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(12,4,4,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(13,4,3,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(14,5,13,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(15,6,14,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(16,7,15,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(17,8,16,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(18,9,17,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(19,10,18,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(20,11,19,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(21,12,20,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(22,13,21,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(23,14,22,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(24,15,23,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(25,16,24,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(26,17,25,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(27,18,26,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(28,19,27,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(29,20,35,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(30,20,34,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(31,20,33,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(32,20,32,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(33,20,31,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(34,20,30,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(35,20,29,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(36,20,28,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(37,21,36,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(38,22,37,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(39,23,38,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(40,24,39,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(41,25,40,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(48,32,47,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(49,33,48,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(51,35,50,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(53,37,52,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(60,44,59,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(61,45,28,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(66,48,64,'2026-09-23 07:24:14.149217','2026-09-23 07:24:14.149217'),(128,78,61,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(129,78,62,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(130,64,128,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(131,65,129,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(132,66,130,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(133,67,131,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(134,68,132,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(135,69,133,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(136,70,134,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(137,71,135,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(138,72,136,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(139,73,137,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(140,74,138,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(141,75,139,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(142,76,140,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(143,77,141,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(144,78,142,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641'),(145,79,143,'2026-09-23 18:15:19.064641','2026-09-23 18:15:19.064641');
/*!40000 ALTER TABLE `concert_artist` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `concert_image`
--

DROP TABLE IF EXISTS `concert_image`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `concert_image` (
  `concert_image_id` bigint NOT NULL AUTO_INCREMENT,
  `concert_id` bigint NOT NULL,
  `image_key` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `purpose` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DETAIL',
  `sort_order` int NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`concert_image_id`)
) ENGINE=InnoDB AUTO_INCREMENT=159 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `concert_image`
--

LOCK TABLES `concert_image` WRITE;
/*!40000 ALTER TABLE `concert_image` DISABLE KEYS */;
INSERT INTO `concert_image` VALUES (1,1,'detail/poster_detail_key_b_day_party_keydult_club_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(2,2,'detail/poster_detail_takuya_kimura_2026_checkpoint_seoul_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(3,2,'detail/poster_detail_takuya_kimura_2026_checkpoint_seoul_1.jpg','DETAIL',1,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(4,2,'detail/poster_detail_takuya_kimura_2026_checkpoint_seoul_2.jpg','DETAIL',2,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(5,3,'detail/poster_detail_gimjanghun_wonmaensyo_jeju_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(6,3,'detail/poster_detail_gimjanghun_wonmaensyo_jeju_1.jpg','DETAIL',1,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(7,3,'detail/poster_detail_gimjanghun_wonmaensyo_jeju_2.jpg','DETAIL',2,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(8,3,'detail/poster_detail_gimjanghun_wonmaensyo_jeju_3.jpg','DETAIL',3,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(9,3,'detail/poster_detail_gimjanghun_wonmaensyo_jeju_4.jpg','DETAIL',4,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(10,4,'detail/poster_detail_chungju_pakeumyujikpeseutibeol_gugak_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(11,4,'detail/poster_detail_chungju_pakeumyujikpeseutibeol_gugak_1.jpg','DETAIL',1,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(12,5,'detail/poster_detail_leo_muse_fanmeeting_take_un_play_leo_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(13,5,'detail/poster_detail_leo_muse_fanmeeting_take_un_play_leo_1.jpg','DETAIL',1,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(14,6,'detail/poster_detail_honggyeongmin_10wolui_maedalriseuteu_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(15,7,'detail/poster_detail_sandeul_baramgyeol_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(16,8,'detail/poster_detail_team_blaze_way_encore_kspo_dome_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(17,8,'detail/poster_detail_team_blaze_way_encore_kspo_dome_1.jpg','DETAIL',1,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(18,9,'detail/poster_detail_reini_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(19,10,'detail/poster_detail_jogwanu_music_gaeului_gijeok_bucheon_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(20,11,'detail/poster_detail_pentagon_10th_anniversary_101010_seoul_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(21,12,'detail/poster_detail_chalri_puseu_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(22,13,'detail/poster_detail_busan_2026_jangyunjeong_master_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(23,14,'detail/poster_detail_gimdongryul_oraedoen_norae_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(24,15,'detail/poster_detail_illit_press_start_encore_korea_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(25,15,'detail/poster_detail_illit_press_start_encore_korea_1.jpg','DETAIL',1,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(26,15,'detail/poster_detail_illit_press_start_encore_korea_2.png','DETAIL',2,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(27,16,'detail/poster_detail_nexz_1st_asia_saucin_world_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(28,17,'detail/poster_detail_ano_seoul_korea_2026_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(29,17,'detail/poster_detail_ano_seoul_korea_2026_1.jpg','DETAIL',1,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(30,17,'detail/poster_detail_ano_seoul_korea_2026_2.jpg','DETAIL',2,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(31,17,'detail/poster_detail_ano_seoul_korea_2026_3.jpg','DETAIL',3,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(32,17,'detail/poster_detail_ano_seoul_korea_2026_4.jpg','DETAIL',4,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(33,18,'detail/poster_detail_iseunggi_giseungjeon_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(34,19,'detail/poster_detail_josyua_redeumeon_kwotet_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(35,20,'detail/poster_detail_gangwon_red_frys_2026_jeonggyutiket_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(36,21,'detail/poster_detail_gimsuhui_uri_dasi_gimsuhui_gwangyang_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(37,22,'detail/poster_detail_simgyuseon_sanctuary_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(38,23,'detail/poster_detail_benseun_bun_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(39,24,'detail/poster_detail_kipeo_kiefer_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(40,25,'detail/poster_detail_gimjaehwan_yeobaek_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(49,32,'detail/poster_detail_morgenshtern_alisher_world_part_2_seoul_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(50,33,'detail/poster_detail_yunjongsin_gaeulnaemsae_daejeon_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(52,35,'detail/poster_detail_daegu_choeyuri_2026_meomureum_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(54,37,'detail/poster_detail_roikim_r_o_y_seoul_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(70,44,'detail/poster_detail_kwon_jin_ah_this_winter_daegu_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(71,45,'detail/poster_detail_dainamik_dyuo_gakkeumssik_orae_boja_busan_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(74,48,'detail/poster_detail_beuruno_maseu_0.jpg','DETAIL',0,'2026-09-23 07:24:14.254284','2026-09-23 07:24:14.254284'),(128,64,'detail/poster_detail_nujabes_metaphorical_ensemble_seoul_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(129,65,'detail/poster_detail_ichangmin_paenmiting_purple_lounge_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(130,65,'detail/poster_detail_ichangmin_paenmiting_purple_lounge_1.jpg','DETAIL',1,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(131,65,'detail/poster_detail_ichangmin_paenmiting_purple_lounge_2.jpg','DETAIL',2,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(132,66,'detail/poster_detail_ko1keyz_1st_fan_meeting_seoul_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(133,67,'detail/poster_detail_debwi_60junyeon_ginyeom_2026_namjin_iksan_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(134,68,'detail/poster_detail_kkachisan_yeogi_kkachisanipnida_daejeon_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(135,69,'detail/poster_detail_ieunmi_okeseuteura_chueoki_pinda_cheongju_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(136,70,'detail/poster_detail_gimpil_journey_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(137,71,'detail/poster_detail_jesi_goldeu_jesse_gold_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(138,72,'detail/poster_detail_let_me_know_2026_re_still_romance_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(139,72,'detail/poster_detail_let_me_know_2026_re_still_romance_1.jpg','DETAIL',1,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(140,72,'detail/poster_detail_let_me_know_2026_re_still_romance_2.jpg','DETAIL',2,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(141,72,'detail/poster_detail_let_me_know_2026_re_still_romance_3.jpg','DETAIL',3,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(142,72,'detail/poster_detail_let_me_know_2026_re_still_romance_4.jpg','DETAIL',4,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(143,72,'detail/poster_detail_let_me_know_2026_re_still_romance_5.jpg','DETAIL',5,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(144,72,'detail/poster_detail_let_me_know_2026_re_still_romance_6.jpg','DETAIL',6,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(145,72,'detail/poster_detail_let_me_know_2026_re_still_romance_7.jpg','DETAIL',7,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(146,72,'detail/poster_detail_let_me_know_2026_re_still_romance_8.jpg','DETAIL',8,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(147,72,'detail/poster_detail_let_me_know_2026_re_still_romance_9.jpg','DETAIL',9,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(148,73,'detail/poster_detail_sunny_day_service_2026_seoul_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(149,74,'detail/poster_detail_yuuri_2026_seoul_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(150,75,'detail/poster_detail_kaki_khaki_one_man_seoul_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(151,76,'detail/poster_detail_kalrideu_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(152,77,'detail/poster_detail_fkj_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(153,78,'detail/poster_detail_kajeumi_tateisi_teurio_jibeuri_jaejeureul_mannada_gwangju_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710'),(154,79,'detail/poster_detail_marun5_0.jpg','DETAIL',0,'2026-09-23 18:15:19.163710','2026-09-23 18:15:19.163710');
/*!40000 ALTER TABLE `concert_image` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `concert_wish`
--

DROP TABLE IF EXISTS `concert_wish`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `concert_wish` (
  `wish_id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `concert_id` bigint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`wish_id`),
  UNIQUE KEY `uk_wish_member_concert` (`member_id`,`concert_id`),
  KEY `idx_wish_concert` (`concert_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `concert_wish`
--

LOCK TABLES `concert_wish` WRITE;
/*!40000 ALTER TABLE `concert_wish` DISABLE KEYS */;
/*!40000 ALTER TABLE `concert_wish` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `goods`
--

DROP TABLE IF EXISTS `goods`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `goods` (
  `goods_id` bigint NOT NULL AUTO_INCREMENT,
  `ticket_id` bigint NOT NULL,
  `member_id` bigint NOT NULL,
  `concert_id` bigint NOT NULL,
  `client_goods_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `background_key` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_background_key` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `person_composite_key` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `depth_map_key` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `preview_key` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `effect_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `background_framing` json DEFAULT NULL,
  `person_layers` json NOT NULL,
  `transition_config` json NOT NULL,
  `render_metadata` json NOT NULL,
  `concert_snapshot` json NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`goods_id`),
  UNIQUE KEY `uk_goods_ticket` (`ticket_id`),
  UNIQUE KEY `uk_goods_member_client` (`member_id`,`client_goods_id`),
  KEY `idx_goods_member_created` (`member_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `goods`
--

LOCK TABLES `goods` WRITE;
/*!40000 ALTER TABLE `goods` DISABLE KEYS */;
/*!40000 ALTER TABLE `goods` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `goods_upload`
--

DROP TABLE IF EXISTS `goods_upload`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `goods_upload` (
  `goods_upload_id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `ticket_id` bigint NOT NULL,
  `image_key` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `deleted_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`goods_upload_id`),
  UNIQUE KEY `uk_goods_upload_image_key` (`image_key`),
  KEY `idx_goods_upload_status_created` (`status`,`created_at`),
  KEY `idx_goods_upload_ticket` (`ticket_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `goods_upload`
--

LOCK TABLES `goods_upload` WRITE;
/*!40000 ALTER TABLE `goods_upload` DISABLE KEYS */;
/*!40000 ALTER TABLE `goods_upload` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `login_info`
--

DROP TABLE IF EXISTS `login_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `login_info` (
  `member_id` bigint NOT NULL,
  `username` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`member_id`),
  UNIQUE KEY `uk_login_info_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `login_info`
--

LOCK TABLES `login_info` WRITE;
/*!40000 ALTER TABLE `login_info` DISABLE KEYS */;
INSERT INTO `login_info` VALUES (2,'admin','$2a$10$qr9tPtEEi2C2Gh4muapuwuQ4ZVEqmTJWjpL21d1gxM6zhdaNBugVW','2026-09-23 16:24:41.014636','2026-09-23 16:24:41.014636'),(3,'jangms1126','$2a$10$Iwt8Ik9fjxeZwefJ.7Ebhevh0Naxirhf8nRObBAqg92KVIWZsMSCy','2026-09-23 21:45:23.083814','2026-09-23 21:45:23.083814'),(4,'okizj','$2a$10$bfVVbUc2zcB7hgy0Ju5C0OqQZ3sdW.O8yy2B7YNkVb/Aaq6xrLlZO','2026-09-24 00:30:41.833963','2026-09-24 00:30:41.833963'),(5,'test','$2a$10$0lt2J29SdR4FVYlyMhTz6.fRXi2iOGk/PwkM8zSa3qAb17L3b2nNy','2026-09-24 20:27:53.857556','2026-09-24 20:27:53.857556');
/*!40000 ALTER TABLE `login_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `member`
--

DROP TABLE IF EXISTS `member`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `member` (
  `member_id` bigint NOT NULL AUTO_INCREMENT,
  `role` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone_number` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `nickname` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`member_id`),
  UNIQUE KEY `uk_member_phone_number` (`phone_number`),
  UNIQUE KEY `uk_member_nickname` (`nickname`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `member`
--

LOCK TABLES `member` WRITE;
/*!40000 ALTER TABLE `member` DISABLE KEYS */;
INSERT INTO `member` VALUES (1,'USER','01064948664','ACTIVE','주최사','ORGANIZER','2026-09-23 16:24:36.599886','2026-09-23 16:24:36.599886'),(2,'ADMIN','01089129650','ACTIVE','관리자','ADMIN','2026-09-23 16:24:40.912300','2026-09-23 16:24:40.912300'),(3,'USER','01049008210','ACTIVE','장민석','제롬','2026-09-23 21:45:22.982361','2026-09-23 21:45:22.982361'),(4,'USER','01063192008','ACTIVE','김유진','유진','2026-09-24 00:30:41.753891','2026-09-24 00:30:41.753891'),(5,'USER','01085459134','ACTIVE','테스트','테스트','2026-09-24 20:27:53.600525','2026-09-24 20:27:53.600525');
/*!40000 ALTER TABLE `member` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notification`
--

DROP TABLE IF EXISTS `notification`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `notification` (
  `notification_id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `body` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `link_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `link_id` bigint DEFAULT NULL,
  `dedup_key` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `read_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`notification_id`),
  UNIQUE KEY `uk_notification_dedup` (`member_id`,`dedup_key`),
  KEY `idx_notification_member` (`member_id`,`notification_id` DESC),
  KEY `idx_notification_unread` (`member_id`,`read_at`),
  KEY `idx_notification_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notification`
--

LOCK TABLES `notification` WRITE;
/*!40000 ALTER TABLE `notification` DISABLE KEYS */;
/*!40000 ALTER TABLE `notification` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `push_device`
--

DROP TABLE IF EXISTS `push_device`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `push_device` (
  `push_device_id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `token` varchar(512) COLLATE utf8mb4_unicode_ci NOT NULL,
  `platform` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`push_device_id`),
  UNIQUE KEY `uk_push_device_token` (`token`),
  KEY `idx_push_device_member` (`member_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `push_device`
--

LOCK TABLES `push_device` WRITE;
/*!40000 ALTER TABLE `push_device` DISABLE KEYS */;
INSERT INTO `push_device` VALUES (2,3,'ehc9sbo7Qkm5StqW7qltNc:APA91bHep14mMc5e5xclTZuK49nhmSROMC2eTbZ2d6VIQCcNua0JAfsHFplzaxVsQ8kCmqqtSz7Lt1XSxKwOuv8HszFGbVyzOJ8DFLh_KyBsEFLFjoPPpKg','android','2026-09-23 21:45:24.757923','2026-09-23 21:45:24.757923'),(4,2,'flFpW4XASmKWy_c1tLrpGw:APA91bEMZ3Ie01wnxziv9nyfBcZS-HMQC2-kK3__z1rbqvswPtweIwYpr_XdER0LyI3RAFj6giiFSE2PCnD8T6s0pvvKaQrb2m66RWB0dRgrDgNKUWA_Y84','android','2026-09-24 16:07:17.891856','2026-09-25 00:15:35.826713'),(5,2,'c_UGU4_gQt-QdjA8T4tnUO:APA91bHRhbxIlOv4AddsufwrVW9Vd6yJIkJ--nmPa83zf0teJiSiQvC8AdazqatcNxsUue7g-bcn_O2Kbn-ocXBioCQ81R1LwW5q-LW7gvE2FLJzERYh1tw','android','2026-09-25 21:31:38.228859','2026-09-25 21:31:38.228859');
/*!40000 ALTER TABLE `push_device` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `refresh_token`
--

DROP TABLE IF EXISTS `refresh_token`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `refresh_token` (
  `refresh_token_id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `device_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token_hash` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`refresh_token_id`),
  UNIQUE KEY `uk_refresh_token_member_device` (`member_id`,`device_id`),
  UNIQUE KEY `uk_refresh_token_hash` (`token_hash`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `refresh_token`
--

LOCK TABLES `refresh_token` WRITE;
/*!40000 ALTER TABLE `refresh_token` DISABLE KEYS */;
INSERT INTO `refresh_token` VALUES (3,3,'4c0ce24a-175d-4500-9ded-8db13ea21c23','50b291037f9d027af695271fdfd6146b253b0be5a1075e815853cd71902ef07d','2026-10-23 21:45:24.606590','2026-09-23 21:45:24.612417','2026-09-23 21:45:24.612417'),(7,2,'a8e6dab4-cd01-48bb-87dd-5140513927d3','4f24b8027c7a6afb968d2bf7f4880d351d0f513bd7580b8fbc5c89fefee3d60f','2026-10-25 21:31:37.944342','2026-09-24 22:57:56.458657','2026-09-25 21:31:37.995299'),(8,2,'383c33d5-be10-4aef-a891-fd01c2001f26','cf398f130b0f1fd947562e2bda88cd6e8a274c383ed9641a1f72b39ce82e107e','2026-10-25 00:15:35.784603','2026-09-24 23:00:05.605654','2026-09-25 00:15:35.790856');
/*!40000 ALTER TABLE `refresh_token` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reservation`
--

DROP TABLE IF EXISTS `reservation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `reservation` (
  `reservation_id` bigint NOT NULL AUTO_INCREMENT,
  `concert_id` bigint NOT NULL,
  `member_id` bigint NOT NULL,
  `seat_id` bigint NOT NULL,
  `cancelled_at` datetime(6) DEFAULT NULL,
  `seat_release_at` datetime(6) DEFAULT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `active_seat` bigint GENERATED ALWAYS AS (if((`status` = _utf8mb4'PAID'),`seat_id`,NULL)) STORED,
  `active_member` bigint GENERATED ALWAYS AS (if((`status` = _utf8mb4'PAID'),`member_id`,NULL)) STORED,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`reservation_id`),
  UNIQUE KEY `uk_rsv_seat` (`concert_id`,`active_seat`),
  UNIQUE KEY `uk_rsv_member` (`concert_id`,`active_member`),
  KEY `ix_rsv_member` (`member_id`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reservation`
--

LOCK TABLES `reservation` WRITE;
/*!40000 ALTER TABLE `reservation` DISABLE KEYS */;
INSERT INTO `reservation` VALUES (1,2,2,1,NULL,NULL,'PAID',1,2,'2026-09-23 16:24:42.901128','2026-09-23 16:24:42.901128'),(2,48,2,35,NULL,NULL,'PAID',35,2,'2026-09-23 16:29:59.210362','2026-09-23 16:29:59.210362'),(3,48,4,142,'2026-09-24 00:31:09.132875','2026-09-24 00:31:09.132875','CANCELLED',NULL,NULL,'2026-09-24 00:31:07.971155','2026-09-24 00:31:09.133463'),(4,48,4,907,NULL,NULL,'PAID',907,4,'2026-09-24 00:31:27.328255','2026-09-24 00:31:27.328255'),(5,12,3,17,NULL,NULL,'PAID',17,3,'2026-09-24 22:55:51.925481','2026-09-24 22:55:51.925481');
/*!40000 ALTER TABLE `reservation` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `seat`
--

DROP TABLE IF EXISTS `seat`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `seat` (
  `seat_id` bigint NOT NULL AUTO_INCREMENT,
  `seat_no` int NOT NULL,
  `seat_col` int NOT NULL,
  `section_id` bigint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`seat_id`),
  UNIQUE KEY `uk_seat_section_position` (`section_id`,`seat_no`,`seat_col`)
) ENGINE=InnoDB AUTO_INCREMENT=1001 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `seat`
--

LOCK TABLES `seat` WRITE;
/*!40000 ALTER TABLE `seat` DISABLE KEYS */;
INSERT INTO `seat` VALUES (1,1,1,1,'2026-09-23 16:24:31.965101','2026-09-23 16:24:31.965101'),(2,1,2,1,'2026-09-23 16:24:31.980439','2026-09-23 16:24:31.980439'),(3,1,3,1,'2026-09-23 16:24:31.989139','2026-09-23 16:24:31.989139'),(4,1,4,1,'2026-09-23 16:24:31.997482','2026-09-23 16:24:31.997482'),(5,1,5,1,'2026-09-23 16:24:32.004891','2026-09-23 16:24:32.004891'),(6,1,6,1,'2026-09-23 16:24:32.014596','2026-09-23 16:24:32.014596'),(7,1,7,1,'2026-09-23 16:24:32.021293','2026-09-23 16:24:32.021293'),(8,1,8,1,'2026-09-23 16:24:32.028989','2026-09-23 16:24:32.028989'),(9,1,9,1,'2026-09-23 16:24:32.039696','2026-09-23 16:24:32.039696'),(10,1,10,1,'2026-09-23 16:24:32.051217','2026-09-23 16:24:32.051217'),(11,1,11,1,'2026-09-23 16:24:32.056323','2026-09-23 16:24:32.056323'),(12,1,12,1,'2026-09-23 16:24:32.063296','2026-09-23 16:24:32.063296'),(13,1,13,1,'2026-09-23 16:24:32.079034','2026-09-23 16:24:32.079034'),(14,1,14,1,'2026-09-23 16:24:32.084526','2026-09-23 16:24:32.084526'),(15,1,15,1,'2026-09-23 16:24:32.091943','2026-09-23 16:24:32.091943'),(16,2,1,1,'2026-09-23 16:24:32.098238','2026-09-23 16:24:32.098238'),(17,2,2,1,'2026-09-23 16:24:32.105650','2026-09-23 16:24:32.105650'),(18,2,3,1,'2026-09-23 16:24:32.111615','2026-09-23 16:24:32.111615'),(19,2,4,1,'2026-09-23 16:24:32.123695','2026-09-23 16:24:32.123695'),(20,2,5,1,'2026-09-23 16:24:32.130042','2026-09-23 16:24:32.130042'),(21,2,6,1,'2026-09-23 16:24:32.138593','2026-09-23 16:24:32.138593'),(22,2,7,1,'2026-09-23 16:24:32.144485','2026-09-23 16:24:32.144485'),(23,2,8,1,'2026-09-23 16:24:32.150366','2026-09-23 16:24:32.150366'),(24,2,9,1,'2026-09-23 16:24:32.156786','2026-09-23 16:24:32.156786'),(25,2,10,1,'2026-09-23 16:24:32.163761','2026-09-23 16:24:32.163761'),(26,2,11,1,'2026-09-23 16:24:32.171877','2026-09-23 16:24:32.171877'),(27,2,12,1,'2026-09-23 16:24:32.183138','2026-09-23 16:24:32.183138'),(28,2,13,1,'2026-09-23 16:24:32.189610','2026-09-23 16:24:32.189610'),(29,2,14,1,'2026-09-23 16:24:32.196598','2026-09-23 16:24:32.196598'),(30,2,15,1,'2026-09-23 16:24:32.203299','2026-09-23 16:24:32.203299'),(31,2,16,1,'2026-09-23 16:24:32.210245','2026-09-23 16:24:32.210245'),(32,3,1,1,'2026-09-23 16:24:32.217129','2026-09-23 16:24:32.217129'),(33,3,2,1,'2026-09-23 16:24:32.221464','2026-09-23 16:24:32.221464'),(34,3,3,1,'2026-09-23 16:24:32.225838','2026-09-23 16:24:32.225838'),(35,3,4,1,'2026-09-23 16:24:32.230491','2026-09-23 16:24:32.230491'),(36,3,5,1,'2026-09-23 16:24:32.235069','2026-09-23 16:24:32.235069'),(37,3,6,1,'2026-09-23 16:24:32.239613','2026-09-23 16:24:32.239613'),(38,3,7,1,'2026-09-23 16:24:32.244186','2026-09-23 16:24:32.244186'),(39,3,8,1,'2026-09-23 16:24:32.248895','2026-09-23 16:24:32.248895'),(40,3,9,1,'2026-09-23 16:24:32.253318','2026-09-23 16:24:32.253318'),(41,3,10,1,'2026-09-23 16:24:32.257675','2026-09-23 16:24:32.257675'),(42,3,11,1,'2026-09-23 16:24:32.262451','2026-09-23 16:24:32.262451'),(43,3,12,1,'2026-09-23 16:24:32.267064','2026-09-23 16:24:32.267064'),(44,3,13,1,'2026-09-23 16:24:32.271046','2026-09-23 16:24:32.271046'),(45,3,14,1,'2026-09-23 16:24:32.274993','2026-09-23 16:24:32.274993'),(46,3,15,1,'2026-09-23 16:24:32.279186','2026-09-23 16:24:32.279186'),(47,3,16,1,'2026-09-23 16:24:32.283541','2026-09-23 16:24:32.283541'),(48,3,17,1,'2026-09-23 16:24:32.287804','2026-09-23 16:24:32.287804'),(49,4,1,1,'2026-09-23 16:24:32.291926','2026-09-23 16:24:32.291926'),(50,4,2,1,'2026-09-23 16:24:32.296224','2026-09-23 16:24:32.296224'),(51,4,3,1,'2026-09-23 16:24:32.300645','2026-09-23 16:24:32.300645'),(52,4,4,1,'2026-09-23 16:24:32.304701','2026-09-23 16:24:32.304701'),(53,4,5,1,'2026-09-23 16:24:32.308564','2026-09-23 16:24:32.308564'),(54,4,6,1,'2026-09-23 16:24:32.312552','2026-09-23 16:24:32.312552'),(55,4,7,1,'2026-09-23 16:24:32.317366','2026-09-23 16:24:32.317366'),(56,4,8,1,'2026-09-23 16:24:32.321451','2026-09-23 16:24:32.321451'),(57,4,9,1,'2026-09-23 16:24:32.325701','2026-09-23 16:24:32.325701'),(58,4,10,1,'2026-09-23 16:24:32.330100','2026-09-23 16:24:32.330100'),(59,4,11,1,'2026-09-23 16:24:32.334162','2026-09-23 16:24:32.334162'),(60,4,12,1,'2026-09-23 16:24:32.338352','2026-09-23 16:24:32.338352'),(61,4,13,1,'2026-09-23 16:24:32.342596','2026-09-23 16:24:32.342596'),(62,4,14,1,'2026-09-23 16:24:32.346397','2026-09-23 16:24:32.346397'),(63,4,15,1,'2026-09-23 16:24:32.350411','2026-09-23 16:24:32.350411'),(64,4,16,1,'2026-09-23 16:24:32.354582','2026-09-23 16:24:32.354582'),(65,4,17,1,'2026-09-23 16:24:32.358821','2026-09-23 16:24:32.358821'),(66,4,18,1,'2026-09-23 16:24:32.362561','2026-09-23 16:24:32.362561'),(67,5,1,1,'2026-09-23 16:24:32.366500','2026-09-23 16:24:32.366500'),(68,5,2,1,'2026-09-23 16:24:32.370312','2026-09-23 16:24:32.370312'),(69,5,3,1,'2026-09-23 16:24:32.374098','2026-09-23 16:24:32.374098'),(70,5,4,1,'2026-09-23 16:24:32.377542','2026-09-23 16:24:32.377542'),(71,5,5,1,'2026-09-23 16:24:32.380815','2026-09-23 16:24:32.380815'),(72,5,6,1,'2026-09-23 16:24:32.386321','2026-09-23 16:24:32.386321'),(73,5,7,1,'2026-09-23 16:24:32.390789','2026-09-23 16:24:32.390789'),(74,5,8,1,'2026-09-23 16:24:32.395685','2026-09-23 16:24:32.395685'),(75,5,9,1,'2026-09-23 16:24:32.399902','2026-09-23 16:24:32.399902'),(76,5,10,1,'2026-09-23 16:24:32.405901','2026-09-23 16:24:32.405901'),(77,5,11,1,'2026-09-23 16:24:32.414459','2026-09-23 16:24:32.414459'),(78,5,12,1,'2026-09-23 16:24:32.420317','2026-09-23 16:24:32.420317'),(79,5,13,1,'2026-09-23 16:24:32.426404','2026-09-23 16:24:32.426404'),(80,5,14,1,'2026-09-23 16:24:32.431592','2026-09-23 16:24:32.431592'),(81,5,15,1,'2026-09-23 16:24:32.437373','2026-09-23 16:24:32.437373'),(82,5,16,1,'2026-09-23 16:24:32.441718','2026-09-23 16:24:32.441718'),(83,5,17,1,'2026-09-23 16:24:32.448117','2026-09-23 16:24:32.448117'),(84,5,18,1,'2026-09-23 16:24:32.452951','2026-09-23 16:24:32.452951'),(85,5,19,1,'2026-09-23 16:24:32.466514','2026-09-23 16:24:32.466514'),(86,6,1,1,'2026-09-23 16:24:32.470435','2026-09-23 16:24:32.470435'),(87,6,2,1,'2026-09-23 16:24:32.474795','2026-09-23 16:24:32.474795'),(88,6,3,1,'2026-09-23 16:24:32.478763','2026-09-23 16:24:32.478763'),(89,6,4,1,'2026-09-23 16:24:32.485830','2026-09-23 16:24:32.485830'),(90,6,5,1,'2026-09-23 16:24:32.490725','2026-09-23 16:24:32.490725'),(91,6,6,1,'2026-09-23 16:24:32.495084','2026-09-23 16:24:32.495084'),(92,6,7,1,'2026-09-23 16:24:32.500280','2026-09-23 16:24:32.500280'),(93,6,8,1,'2026-09-23 16:24:32.504462','2026-09-23 16:24:32.504462'),(94,6,9,1,'2026-09-23 16:24:32.509954','2026-09-23 16:24:32.509954'),(95,6,10,1,'2026-09-23 16:24:32.514336','2026-09-23 16:24:32.514336'),(96,6,11,1,'2026-09-23 16:24:32.520470','2026-09-23 16:24:32.520470'),(97,6,12,1,'2026-09-23 16:24:32.525088','2026-09-23 16:24:32.525088'),(98,6,13,1,'2026-09-23 16:24:32.530120','2026-09-23 16:24:32.530120'),(99,6,14,1,'2026-09-23 16:24:32.535944','2026-09-23 16:24:32.535944'),(100,6,15,1,'2026-09-23 16:24:32.540989','2026-09-23 16:24:32.540989'),(101,6,16,1,'2026-09-23 16:24:32.547379','2026-09-23 16:24:32.547379'),(102,6,17,1,'2026-09-23 16:24:32.556446','2026-09-23 16:24:32.556446'),(103,6,18,1,'2026-09-23 16:24:32.570065','2026-09-23 16:24:32.570065'),(104,6,19,1,'2026-09-23 16:24:32.576695','2026-09-23 16:24:32.576695'),(105,6,20,1,'2026-09-23 16:24:32.582334','2026-09-23 16:24:32.582334'),(106,6,21,1,'2026-09-23 16:24:32.588127','2026-09-23 16:24:32.588127'),(107,7,1,1,'2026-09-23 16:24:32.593085','2026-09-23 16:24:32.593085'),(108,7,2,1,'2026-09-23 16:24:32.596840','2026-09-23 16:24:32.596840'),(109,7,3,1,'2026-09-23 16:24:32.600601','2026-09-23 16:24:32.600601'),(110,7,4,1,'2026-09-23 16:24:32.614609','2026-09-23 16:24:32.614609'),(111,7,5,1,'2026-09-23 16:24:32.624288','2026-09-23 16:24:32.624288'),(112,7,6,1,'2026-09-23 16:24:32.629303','2026-09-23 16:24:32.629303'),(113,7,7,1,'2026-09-23 16:24:32.641713','2026-09-23 16:24:32.641713'),(114,7,8,1,'2026-09-23 16:24:32.645848','2026-09-23 16:24:32.645848'),(115,7,9,1,'2026-09-23 16:24:32.650375','2026-09-23 16:24:32.650375'),(116,7,10,1,'2026-09-23 16:24:32.658256','2026-09-23 16:24:32.658256'),(117,7,11,1,'2026-09-23 16:24:32.661961','2026-09-23 16:24:32.661961'),(118,7,12,1,'2026-09-23 16:24:32.668691','2026-09-23 16:24:32.668691'),(119,7,13,1,'2026-09-23 16:24:32.672562','2026-09-23 16:24:32.672562'),(120,7,14,1,'2026-09-23 16:24:32.677096','2026-09-23 16:24:32.677096'),(121,7,15,1,'2026-09-23 16:24:32.681233','2026-09-23 16:24:32.681233'),(122,7,16,1,'2026-09-23 16:24:32.684878','2026-09-23 16:24:32.684878'),(123,7,17,1,'2026-09-23 16:24:32.688845','2026-09-23 16:24:32.688845'),(124,7,18,1,'2026-09-23 16:24:32.692893','2026-09-23 16:24:32.692893'),(125,7,19,1,'2026-09-23 16:24:32.696501','2026-09-23 16:24:32.696501'),(126,7,20,1,'2026-09-23 16:24:32.700124','2026-09-23 16:24:32.700124'),(127,7,21,1,'2026-09-23 16:24:32.704574','2026-09-23 16:24:32.704574'),(128,7,22,1,'2026-09-23 16:24:32.709040','2026-09-23 16:24:32.709040'),(129,8,1,1,'2026-09-23 16:24:32.714033','2026-09-23 16:24:32.714033'),(130,8,2,1,'2026-09-23 16:24:32.717859','2026-09-23 16:24:32.717859'),(131,8,3,1,'2026-09-23 16:24:32.721499','2026-09-23 16:24:32.721499'),(132,8,4,1,'2026-09-23 16:24:32.725040','2026-09-23 16:24:32.725040'),(133,8,5,1,'2026-09-23 16:24:32.728831','2026-09-23 16:24:32.728831'),(134,8,6,1,'2026-09-23 16:24:32.732580','2026-09-23 16:24:32.732580'),(135,8,7,1,'2026-09-23 16:24:32.736304','2026-09-23 16:24:32.736304'),(136,8,8,1,'2026-09-23 16:24:32.739945','2026-09-23 16:24:32.739945'),(137,8,9,1,'2026-09-23 16:24:32.743746','2026-09-23 16:24:32.743746'),(138,8,10,1,'2026-09-23 16:24:32.747848','2026-09-23 16:24:32.747848'),(139,8,11,1,'2026-09-23 16:24:32.751707','2026-09-23 16:24:32.751707'),(140,8,12,1,'2026-09-23 16:24:32.755428','2026-09-23 16:24:32.755428'),(141,8,13,1,'2026-09-23 16:24:32.759302','2026-09-23 16:24:32.759302'),(142,8,14,1,'2026-09-23 16:24:32.762876','2026-09-23 16:24:32.762876'),(143,8,15,1,'2026-09-23 16:24:32.766772','2026-09-23 16:24:32.766772'),(144,8,16,1,'2026-09-23 16:24:32.770557','2026-09-23 16:24:32.770557'),(145,8,17,1,'2026-09-23 16:24:32.775313','2026-09-23 16:24:32.775313'),(146,8,18,1,'2026-09-23 16:24:32.779088','2026-09-23 16:24:32.779088'),(147,8,19,1,'2026-09-23 16:24:32.782890','2026-09-23 16:24:32.782890'),(148,8,20,1,'2026-09-23 16:24:32.786788','2026-09-23 16:24:32.786788'),(149,8,21,1,'2026-09-23 16:24:32.790704','2026-09-23 16:24:32.790704'),(150,8,22,1,'2026-09-23 16:24:32.794907','2026-09-23 16:24:32.794907'),(151,8,23,1,'2026-09-23 16:24:32.798678','2026-09-23 16:24:32.798678'),(152,9,1,1,'2026-09-23 16:24:32.802645','2026-09-23 16:24:32.802645'),(153,9,2,1,'2026-09-23 16:24:32.806618','2026-09-23 16:24:32.806618'),(154,9,3,1,'2026-09-23 16:24:32.810790','2026-09-23 16:24:32.810790'),(155,9,4,1,'2026-09-23 16:24:32.814896','2026-09-23 16:24:32.814896'),(156,9,5,1,'2026-09-23 16:24:32.819042','2026-09-23 16:24:32.819042'),(157,9,6,1,'2026-09-23 16:24:32.823283','2026-09-23 16:24:32.823283'),(158,9,7,1,'2026-09-23 16:24:32.827033','2026-09-23 16:24:32.827033'),(159,9,8,1,'2026-09-23 16:24:32.831146','2026-09-23 16:24:32.831146'),(160,9,9,1,'2026-09-23 16:24:32.835120','2026-09-23 16:24:32.835120'),(161,9,10,1,'2026-09-23 16:24:32.838927','2026-09-23 16:24:32.838927'),(162,9,11,1,'2026-09-23 16:24:32.842713','2026-09-23 16:24:32.842713'),(163,9,12,1,'2026-09-23 16:24:32.846399','2026-09-23 16:24:32.846399'),(164,9,13,1,'2026-09-23 16:24:32.850060','2026-09-23 16:24:32.850060'),(165,9,14,1,'2026-09-23 16:24:32.853851','2026-09-23 16:24:32.853851'),(166,9,15,1,'2026-09-23 16:24:32.857502','2026-09-23 16:24:32.857502'),(167,9,16,1,'2026-09-23 16:24:32.861023','2026-09-23 16:24:32.861023'),(168,9,17,1,'2026-09-23 16:24:32.865836','2026-09-23 16:24:32.865836'),(169,9,18,1,'2026-09-23 16:24:32.874219','2026-09-23 16:24:32.874219'),(170,9,19,1,'2026-09-23 16:24:32.884262','2026-09-23 16:24:32.884262'),(171,9,20,1,'2026-09-23 16:24:32.888236','2026-09-23 16:24:32.888236'),(172,9,21,1,'2026-09-23 16:24:32.892202','2026-09-23 16:24:32.892202'),(173,9,22,1,'2026-09-23 16:24:32.896055','2026-09-23 16:24:32.896055'),(174,9,23,1,'2026-09-23 16:24:32.899736','2026-09-23 16:24:32.899736'),(175,9,24,1,'2026-09-23 16:24:32.903686','2026-09-23 16:24:32.903686'),(176,10,1,1,'2026-09-23 16:24:32.907437','2026-09-23 16:24:32.907437'),(177,10,2,1,'2026-09-23 16:24:32.911141','2026-09-23 16:24:32.911141'),(178,10,3,1,'2026-09-23 16:24:32.915292','2026-09-23 16:24:32.915292'),(179,10,4,1,'2026-09-23 16:24:32.918912','2026-09-23 16:24:32.918912'),(180,10,5,1,'2026-09-23 16:24:32.922816','2026-09-23 16:24:32.922816'),(181,10,6,1,'2026-09-23 16:24:32.926503','2026-09-23 16:24:32.926503'),(182,10,7,1,'2026-09-23 16:24:32.930557','2026-09-23 16:24:32.930557'),(183,10,8,1,'2026-09-23 16:24:32.934756','2026-09-23 16:24:32.934756'),(184,10,9,1,'2026-09-23 16:24:32.939886','2026-09-23 16:24:32.939886'),(185,10,10,1,'2026-09-23 16:24:32.948994','2026-09-23 16:24:32.948994'),(186,10,11,1,'2026-09-23 16:24:32.955761','2026-09-23 16:24:32.955761'),(187,10,12,1,'2026-09-23 16:24:32.960371','2026-09-23 16:24:32.960371'),(188,10,13,1,'2026-09-23 16:24:32.967015','2026-09-23 16:24:32.967015'),(189,10,14,1,'2026-09-23 16:24:32.973910','2026-09-23 16:24:32.973910'),(190,10,15,1,'2026-09-23 16:24:32.978580','2026-09-23 16:24:32.978580'),(191,10,16,1,'2026-09-23 16:24:32.983962','2026-09-23 16:24:32.983962'),(192,10,17,1,'2026-09-23 16:24:32.988539','2026-09-23 16:24:32.988539'),(193,10,18,1,'2026-09-23 16:24:32.994078','2026-09-23 16:24:32.994078'),(194,10,19,1,'2026-09-23 16:24:32.997302','2026-09-23 16:24:32.997302'),(195,10,20,1,'2026-09-23 16:24:33.000697','2026-09-23 16:24:33.000697'),(196,10,21,1,'2026-09-23 16:24:33.010730','2026-09-23 16:24:33.010730'),(197,10,22,1,'2026-09-23 16:24:33.016928','2026-09-23 16:24:33.016928'),(198,10,23,1,'2026-09-23 16:24:33.022085','2026-09-23 16:24:33.022085'),(199,10,24,1,'2026-09-23 16:24:33.027110','2026-09-23 16:24:33.027110'),(200,10,25,1,'2026-09-23 16:24:33.030937','2026-09-23 16:24:33.030937'),(201,1,1,2,'2026-09-23 16:24:33.044615','2026-09-23 16:24:33.044615'),(202,1,2,2,'2026-09-23 16:24:33.048720','2026-09-23 16:24:33.048720'),(203,1,3,2,'2026-09-23 16:24:33.056378','2026-09-23 16:24:33.056378'),(204,1,4,2,'2026-09-23 16:24:33.060831','2026-09-23 16:24:33.060831'),(205,1,5,2,'2026-09-23 16:24:33.073020','2026-09-23 16:24:33.073020'),(206,1,6,2,'2026-09-23 16:24:33.077033','2026-09-23 16:24:33.077033'),(207,1,7,2,'2026-09-23 16:24:33.080830','2026-09-23 16:24:33.080830'),(208,1,8,2,'2026-09-23 16:24:33.086549','2026-09-23 16:24:33.086549'),(209,1,9,2,'2026-09-23 16:24:33.090660','2026-09-23 16:24:33.090660'),(210,1,10,2,'2026-09-23 16:24:33.094609','2026-09-23 16:24:33.094609'),(211,1,11,2,'2026-09-23 16:24:33.099636','2026-09-23 16:24:33.099636'),(212,1,12,2,'2026-09-23 16:24:33.104734','2026-09-23 16:24:33.104734'),(213,1,13,2,'2026-09-23 16:24:33.108964','2026-09-23 16:24:33.108964'),(214,1,14,2,'2026-09-23 16:24:33.114309','2026-09-23 16:24:33.114309'),(215,1,15,2,'2026-09-23 16:24:33.119084','2026-09-23 16:24:33.119084'),(216,2,1,2,'2026-09-23 16:24:33.127433','2026-09-23 16:24:33.127433'),(217,2,2,2,'2026-09-23 16:24:33.131643','2026-09-23 16:24:33.131643'),(218,2,3,2,'2026-09-23 16:24:33.139058','2026-09-23 16:24:33.139058'),(219,2,4,2,'2026-09-23 16:24:33.144437','2026-09-23 16:24:33.144437'),(220,2,5,2,'2026-09-23 16:24:33.148669','2026-09-23 16:24:33.148669'),(221,2,6,2,'2026-09-23 16:24:33.153597','2026-09-23 16:24:33.153597'),(222,2,7,2,'2026-09-23 16:24:33.159522','2026-09-23 16:24:33.159522'),(223,2,8,2,'2026-09-23 16:24:33.164745','2026-09-23 16:24:33.164745'),(224,2,9,2,'2026-09-23 16:24:33.170055','2026-09-23 16:24:33.170055'),(225,2,10,2,'2026-09-23 16:24:33.175969','2026-09-23 16:24:33.175969'),(226,2,11,2,'2026-09-23 16:24:33.182031','2026-09-23 16:24:33.182031'),(227,2,12,2,'2026-09-23 16:24:33.188647','2026-09-23 16:24:33.188647'),(228,2,13,2,'2026-09-23 16:24:33.193813','2026-09-23 16:24:33.193813'),(229,2,14,2,'2026-09-23 16:24:33.203522','2026-09-23 16:24:33.203522'),(230,2,15,2,'2026-09-23 16:24:33.207651','2026-09-23 16:24:33.207651'),(231,2,16,2,'2026-09-23 16:24:33.211059','2026-09-23 16:24:33.211059'),(232,3,1,2,'2026-09-23 16:24:33.218163','2026-09-23 16:24:33.218163'),(233,3,2,2,'2026-09-23 16:24:33.227835','2026-09-23 16:24:33.227835'),(234,3,3,2,'2026-09-23 16:24:33.231586','2026-09-23 16:24:33.231586'),(235,3,4,2,'2026-09-23 16:24:33.238403','2026-09-23 16:24:33.238403'),(236,3,5,2,'2026-09-23 16:24:33.242658','2026-09-23 16:24:33.242658'),(237,3,6,2,'2026-09-23 16:24:33.250218','2026-09-23 16:24:33.250218'),(238,3,7,2,'2026-09-23 16:24:33.254196','2026-09-23 16:24:33.254196'),(239,3,8,2,'2026-09-23 16:24:33.257923','2026-09-23 16:24:33.257923'),(240,3,9,2,'2026-09-23 16:24:33.261301','2026-09-23 16:24:33.261301'),(241,3,10,2,'2026-09-23 16:24:33.265438','2026-09-23 16:24:33.265438'),(242,3,11,2,'2026-09-23 16:24:33.269052','2026-09-23 16:24:33.269052'),(243,3,12,2,'2026-09-23 16:24:33.272479','2026-09-23 16:24:33.272479'),(244,3,13,2,'2026-09-23 16:24:33.276789','2026-09-23 16:24:33.276789'),(245,3,14,2,'2026-09-23 16:24:33.280554','2026-09-23 16:24:33.280554'),(246,3,15,2,'2026-09-23 16:24:33.284059','2026-09-23 16:24:33.284059'),(247,3,16,2,'2026-09-23 16:24:33.289743','2026-09-23 16:24:33.289743'),(248,3,17,2,'2026-09-23 16:24:33.294202','2026-09-23 16:24:33.294202'),(249,4,1,2,'2026-09-23 16:24:33.297989','2026-09-23 16:24:33.297989'),(250,4,2,2,'2026-09-23 16:24:33.302604','2026-09-23 16:24:33.302604'),(251,4,3,2,'2026-09-23 16:24:33.314240','2026-09-23 16:24:33.314240'),(252,4,4,2,'2026-09-23 16:24:33.318736','2026-09-23 16:24:33.318736'),(253,4,5,2,'2026-09-23 16:24:33.324102','2026-09-23 16:24:33.324102'),(254,4,6,2,'2026-09-23 16:24:33.332009','2026-09-23 16:24:33.332009'),(255,4,7,2,'2026-09-23 16:24:33.339003','2026-09-23 16:24:33.339003'),(256,4,8,2,'2026-09-23 16:24:33.342531','2026-09-23 16:24:33.342531'),(257,4,9,2,'2026-09-23 16:24:33.348287','2026-09-23 16:24:33.348287'),(258,4,10,2,'2026-09-23 16:24:33.353841','2026-09-23 16:24:33.353841'),(259,4,11,2,'2026-09-23 16:24:33.364130','2026-09-23 16:24:33.364130'),(260,4,12,2,'2026-09-23 16:24:33.367676','2026-09-23 16:24:33.367676'),(261,4,13,2,'2026-09-23 16:24:33.370357','2026-09-23 16:24:33.370357'),(262,4,14,2,'2026-09-23 16:24:33.377500','2026-09-23 16:24:33.377500'),(263,4,15,2,'2026-09-23 16:24:33.380693','2026-09-23 16:24:33.380693'),(264,4,16,2,'2026-09-23 16:24:33.384039','2026-09-23 16:24:33.384039'),(265,4,17,2,'2026-09-23 16:24:33.387492','2026-09-23 16:24:33.387492'),(266,4,18,2,'2026-09-23 16:24:33.393026','2026-09-23 16:24:33.393026'),(267,5,1,2,'2026-09-23 16:24:33.401845','2026-09-23 16:24:33.401845'),(268,5,2,2,'2026-09-23 16:24:33.405580','2026-09-23 16:24:33.405580'),(269,5,3,2,'2026-09-23 16:24:33.412286','2026-09-23 16:24:33.412286'),(270,5,4,2,'2026-09-23 16:24:33.419039','2026-09-23 16:24:33.419039'),(271,5,5,2,'2026-09-23 16:24:33.424573','2026-09-23 16:24:33.424573'),(272,5,6,2,'2026-09-23 16:24:33.428377','2026-09-23 16:24:33.428377'),(273,5,7,2,'2026-09-23 16:24:33.432586','2026-09-23 16:24:33.432586'),(274,5,8,2,'2026-09-23 16:24:33.440271','2026-09-23 16:24:33.440271'),(275,5,9,2,'2026-09-23 16:24:33.447529','2026-09-23 16:24:33.447529'),(276,5,10,2,'2026-09-23 16:24:33.452617','2026-09-23 16:24:33.452617'),(277,5,11,2,'2026-09-23 16:24:33.456992','2026-09-23 16:24:33.456992'),(278,5,12,2,'2026-09-23 16:24:33.460744','2026-09-23 16:24:33.460744'),(279,5,13,2,'2026-09-23 16:24:33.464013','2026-09-23 16:24:33.464013'),(280,5,14,2,'2026-09-23 16:24:33.466866','2026-09-23 16:24:33.466866'),(281,5,15,2,'2026-09-23 16:24:33.470357','2026-09-23 16:24:33.470357'),(282,5,16,2,'2026-09-23 16:24:33.473933','2026-09-23 16:24:33.473933'),(283,5,17,2,'2026-09-23 16:24:33.477467','2026-09-23 16:24:33.477467'),(284,5,18,2,'2026-09-23 16:24:33.480961','2026-09-23 16:24:33.480961'),(285,5,19,2,'2026-09-23 16:24:33.484892','2026-09-23 16:24:33.484892'),(286,6,1,2,'2026-09-23 16:24:33.488230','2026-09-23 16:24:33.488230'),(287,6,2,2,'2026-09-23 16:24:33.491161','2026-09-23 16:24:33.491161'),(288,6,3,2,'2026-09-23 16:24:33.494572','2026-09-23 16:24:33.494572'),(289,6,4,2,'2026-09-23 16:24:33.497851','2026-09-23 16:24:33.497851'),(290,6,5,2,'2026-09-23 16:24:33.500944','2026-09-23 16:24:33.500944'),(291,6,6,2,'2026-09-23 16:24:33.513910','2026-09-23 16:24:33.513910'),(292,6,7,2,'2026-09-23 16:24:33.517428','2026-09-23 16:24:33.517428'),(293,6,8,2,'2026-09-23 16:24:33.520820','2026-09-23 16:24:33.520820'),(294,6,9,2,'2026-09-23 16:24:33.524106','2026-09-23 16:24:33.524106'),(295,6,10,2,'2026-09-23 16:24:33.530421','2026-09-23 16:24:33.530421'),(296,6,11,2,'2026-09-23 16:24:33.533625','2026-09-23 16:24:33.533625'),(297,6,12,2,'2026-09-23 16:24:33.543362','2026-09-23 16:24:33.543362'),(298,6,13,2,'2026-09-23 16:24:33.547071','2026-09-23 16:24:33.547071'),(299,6,14,2,'2026-09-23 16:24:33.553989','2026-09-23 16:24:33.553989'),(300,6,15,2,'2026-09-23 16:24:33.557428','2026-09-23 16:24:33.557428'),(301,6,16,2,'2026-09-23 16:24:33.563448','2026-09-23 16:24:33.563448'),(302,6,17,2,'2026-09-23 16:24:33.566658','2026-09-23 16:24:33.566658'),(303,6,18,2,'2026-09-23 16:24:33.569831','2026-09-23 16:24:33.569831'),(304,6,19,2,'2026-09-23 16:24:33.574945','2026-09-23 16:24:33.574945'),(305,6,20,2,'2026-09-23 16:24:33.578315','2026-09-23 16:24:33.578315'),(306,6,21,2,'2026-09-23 16:24:33.584023','2026-09-23 16:24:33.584023'),(307,7,1,2,'2026-09-23 16:24:33.587057','2026-09-23 16:24:33.587057'),(308,7,2,2,'2026-09-23 16:24:33.590511','2026-09-23 16:24:33.590511'),(309,7,3,2,'2026-09-23 16:24:33.593717','2026-09-23 16:24:33.593717'),(310,7,4,2,'2026-09-23 16:24:33.596383','2026-09-23 16:24:33.596383'),(311,7,5,2,'2026-09-23 16:24:33.599721','2026-09-23 16:24:33.599721'),(312,7,6,2,'2026-09-23 16:24:33.602868','2026-09-23 16:24:33.602868'),(313,7,7,2,'2026-09-23 16:24:33.606074','2026-09-23 16:24:33.606074'),(314,7,8,2,'2026-09-23 16:24:33.608704','2026-09-23 16:24:33.608704'),(315,7,9,2,'2026-09-23 16:24:33.612278','2026-09-23 16:24:33.612278'),(316,7,10,2,'2026-09-23 16:24:33.615665','2026-09-23 16:24:33.615665'),(317,7,11,2,'2026-09-23 16:24:33.618858','2026-09-23 16:24:33.618858'),(318,7,12,2,'2026-09-23 16:24:33.622470','2026-09-23 16:24:33.622470'),(319,7,13,2,'2026-09-23 16:24:33.626742','2026-09-23 16:24:33.626742'),(320,7,14,2,'2026-09-23 16:24:33.630324','2026-09-23 16:24:33.630324'),(321,7,15,2,'2026-09-23 16:24:33.633387','2026-09-23 16:24:33.633387'),(322,7,16,2,'2026-09-23 16:24:33.636752','2026-09-23 16:24:33.636752'),(323,7,17,2,'2026-09-23 16:24:33.640171','2026-09-23 16:24:33.640171'),(324,7,18,2,'2026-09-23 16:24:33.644122','2026-09-23 16:24:33.644122'),(325,7,19,2,'2026-09-23 16:24:33.646929','2026-09-23 16:24:33.646929'),(326,7,20,2,'2026-09-23 16:24:33.650607','2026-09-23 16:24:33.650607'),(327,7,21,2,'2026-09-23 16:24:33.653807','2026-09-23 16:24:33.653807'),(328,7,22,2,'2026-09-23 16:24:33.656928','2026-09-23 16:24:33.656928'),(329,8,1,2,'2026-09-23 16:24:33.660217','2026-09-23 16:24:33.660217'),(330,8,2,2,'2026-09-23 16:24:33.663484','2026-09-23 16:24:33.663484'),(331,8,3,2,'2026-09-23 16:24:33.666610','2026-09-23 16:24:33.666610'),(332,8,4,2,'2026-09-23 16:24:33.669740','2026-09-23 16:24:33.669740'),(333,8,5,2,'2026-09-23 16:24:33.673065','2026-09-23 16:24:33.673065'),(334,8,6,2,'2026-09-23 16:24:33.676313','2026-09-23 16:24:33.676313'),(335,8,7,2,'2026-09-23 16:24:33.679423','2026-09-23 16:24:33.679423'),(336,8,8,2,'2026-09-23 16:24:33.682093','2026-09-23 16:24:33.682093'),(337,8,9,2,'2026-09-23 16:24:33.685335','2026-09-23 16:24:33.685335'),(338,8,10,2,'2026-09-23 16:24:33.688273','2026-09-23 16:24:33.688273'),(339,8,11,2,'2026-09-23 16:24:33.691442','2026-09-23 16:24:33.691442'),(340,8,12,2,'2026-09-23 16:24:33.695011','2026-09-23 16:24:33.695011'),(341,8,13,2,'2026-09-23 16:24:33.698232','2026-09-23 16:24:33.698232'),(342,8,14,2,'2026-09-23 16:24:33.701568','2026-09-23 16:24:33.701568'),(343,8,15,2,'2026-09-23 16:24:33.705032','2026-09-23 16:24:33.705032'),(344,8,16,2,'2026-09-23 16:24:33.708350','2026-09-23 16:24:33.708350'),(345,8,17,2,'2026-09-23 16:24:33.711739','2026-09-23 16:24:33.711739'),(346,8,18,2,'2026-09-23 16:24:33.715109','2026-09-23 16:24:33.715109'),(347,8,19,2,'2026-09-23 16:24:33.718459','2026-09-23 16:24:33.718459'),(348,8,20,2,'2026-09-23 16:24:33.722006','2026-09-23 16:24:33.722006'),(349,8,21,2,'2026-09-23 16:24:33.726107','2026-09-23 16:24:33.726107'),(350,8,22,2,'2026-09-23 16:24:33.733115','2026-09-23 16:24:33.733115'),(351,8,23,2,'2026-09-23 16:24:33.740042','2026-09-23 16:24:33.740042'),(352,9,1,2,'2026-09-23 16:24:33.745369','2026-09-23 16:24:33.745369'),(353,9,2,2,'2026-09-23 16:24:33.749950','2026-09-23 16:24:33.749950'),(354,9,3,2,'2026-09-23 16:24:33.753747','2026-09-23 16:24:33.753747'),(355,9,4,2,'2026-09-23 16:24:33.757069','2026-09-23 16:24:33.757069'),(356,9,5,2,'2026-09-23 16:24:33.760485','2026-09-23 16:24:33.760485'),(357,9,6,2,'2026-09-23 16:24:33.763774','2026-09-23 16:24:33.763774'),(358,9,7,2,'2026-09-23 16:24:33.767074','2026-09-23 16:24:33.767074'),(359,9,8,2,'2026-09-23 16:24:33.770456','2026-09-23 16:24:33.770456'),(360,9,9,2,'2026-09-23 16:24:33.774196','2026-09-23 16:24:33.774196'),(361,9,10,2,'2026-09-23 16:24:33.777471','2026-09-23 16:24:33.777471'),(362,9,11,2,'2026-09-23 16:24:33.780568','2026-09-23 16:24:33.780568'),(363,9,12,2,'2026-09-23 16:24:33.783681','2026-09-23 16:24:33.783681'),(364,9,13,2,'2026-09-23 16:24:33.786351','2026-09-23 16:24:33.786351'),(365,9,14,2,'2026-09-23 16:24:33.789835','2026-09-23 16:24:33.789835'),(366,9,15,2,'2026-09-23 16:24:33.793235','2026-09-23 16:24:33.793235'),(367,9,16,2,'2026-09-23 16:24:33.796560','2026-09-23 16:24:33.796560'),(368,9,17,2,'2026-09-23 16:24:33.800484','2026-09-23 16:24:33.800484'),(369,9,18,2,'2026-09-23 16:24:33.804236','2026-09-23 16:24:33.804236'),(370,9,19,2,'2026-09-23 16:24:33.807449','2026-09-23 16:24:33.807449'),(371,9,20,2,'2026-09-23 16:24:33.810606','2026-09-23 16:24:33.810606'),(372,9,21,2,'2026-09-23 16:24:33.815466','2026-09-23 16:24:33.815466'),(373,9,22,2,'2026-09-23 16:24:33.821471','2026-09-23 16:24:33.821471'),(374,9,23,2,'2026-09-23 16:24:33.825246','2026-09-23 16:24:33.825246'),(375,9,24,2,'2026-09-23 16:24:33.828866','2026-09-23 16:24:33.828866'),(376,10,1,2,'2026-09-23 16:24:33.832547','2026-09-23 16:24:33.832547'),(377,10,2,2,'2026-09-23 16:24:33.836699','2026-09-23 16:24:33.836699'),(378,10,3,2,'2026-09-23 16:24:33.839647','2026-09-23 16:24:33.839647'),(379,10,4,2,'2026-09-23 16:24:33.842770','2026-09-23 16:24:33.842770'),(380,10,5,2,'2026-09-23 16:24:33.845972','2026-09-23 16:24:33.845972'),(381,10,6,2,'2026-09-23 16:24:33.849341','2026-09-23 16:24:33.849341'),(382,10,7,2,'2026-09-23 16:24:33.852936','2026-09-23 16:24:33.852936'),(383,10,8,2,'2026-09-23 16:24:33.856763','2026-09-23 16:24:33.856763'),(384,10,9,2,'2026-09-23 16:24:33.860809','2026-09-23 16:24:33.860809'),(385,10,10,2,'2026-09-23 16:24:33.867110','2026-09-23 16:24:33.867110'),(386,10,11,2,'2026-09-23 16:24:33.870387','2026-09-23 16:24:33.870387'),(387,10,12,2,'2026-09-23 16:24:33.873575','2026-09-23 16:24:33.873575'),(388,10,13,2,'2026-09-23 16:24:33.876612','2026-09-23 16:24:33.876612'),(389,10,14,2,'2026-09-23 16:24:33.879459','2026-09-23 16:24:33.879459'),(390,10,15,2,'2026-09-23 16:24:33.883880','2026-09-23 16:24:33.883880'),(391,10,16,2,'2026-09-23 16:24:33.886835','2026-09-23 16:24:33.886835'),(392,10,17,2,'2026-09-23 16:24:33.894033','2026-09-23 16:24:33.894033'),(393,10,18,2,'2026-09-23 16:24:33.897439','2026-09-23 16:24:33.897439'),(394,10,19,2,'2026-09-23 16:24:33.900756','2026-09-23 16:24:33.900756'),(395,10,20,2,'2026-09-23 16:24:33.904814','2026-09-23 16:24:33.904814'),(396,10,21,2,'2026-09-23 16:24:33.908521','2026-09-23 16:24:33.908521'),(397,10,22,2,'2026-09-23 16:24:33.911679','2026-09-23 16:24:33.911679'),(398,10,23,2,'2026-09-23 16:24:33.914635','2026-09-23 16:24:33.914635'),(399,10,24,2,'2026-09-23 16:24:33.918158','2026-09-23 16:24:33.918158'),(400,10,25,2,'2026-09-23 16:24:33.921397','2026-09-23 16:24:33.921397'),(401,1,1,3,'2026-09-23 16:24:33.933176','2026-09-23 16:24:33.933176'),(402,1,2,3,'2026-09-23 16:24:33.938829','2026-09-23 16:24:33.938829'),(403,1,3,3,'2026-09-23 16:24:33.943520','2026-09-23 16:24:33.943520'),(404,1,4,3,'2026-09-23 16:24:33.946865','2026-09-23 16:24:33.946865'),(405,1,5,3,'2026-09-23 16:24:33.949855','2026-09-23 16:24:33.949855'),(406,1,6,3,'2026-09-23 16:24:33.969739','2026-09-23 16:24:33.969739'),(407,1,7,3,'2026-09-23 16:24:33.973692','2026-09-23 16:24:33.973692'),(408,1,8,3,'2026-09-23 16:24:33.976768','2026-09-23 16:24:33.976768'),(409,1,9,3,'2026-09-23 16:24:33.979203','2026-09-23 16:24:33.979203'),(410,1,10,3,'2026-09-23 16:24:33.982175','2026-09-23 16:24:33.982175'),(411,1,11,3,'2026-09-23 16:24:33.985692','2026-09-23 16:24:33.985692'),(412,1,12,3,'2026-09-23 16:24:33.989159','2026-09-23 16:24:33.989159'),(413,1,13,3,'2026-09-23 16:24:33.992378','2026-09-23 16:24:33.992378'),(414,1,14,3,'2026-09-23 16:24:33.995503','2026-09-23 16:24:33.995503'),(415,1,15,3,'2026-09-23 16:24:33.998009','2026-09-23 16:24:33.998009'),(416,1,16,3,'2026-09-23 16:24:34.000576','2026-09-23 16:24:34.000576'),(417,1,17,3,'2026-09-23 16:24:34.006565','2026-09-23 16:24:34.006565'),(418,1,18,3,'2026-09-23 16:24:34.010747','2026-09-23 16:24:34.010747'),(419,2,1,3,'2026-09-23 16:24:34.013993','2026-09-23 16:24:34.013993'),(420,2,2,3,'2026-09-23 16:24:34.017048','2026-09-23 16:24:34.017048'),(421,2,3,3,'2026-09-23 16:24:34.020163','2026-09-23 16:24:34.020163'),(422,2,4,3,'2026-09-23 16:24:34.023424','2026-09-23 16:24:34.023424'),(423,2,5,3,'2026-09-23 16:24:34.026325','2026-09-23 16:24:34.026325'),(424,2,6,3,'2026-09-23 16:24:34.029186','2026-09-23 16:24:34.029186'),(425,2,7,3,'2026-09-23 16:24:34.032200','2026-09-23 16:24:34.032200'),(426,2,8,3,'2026-09-23 16:24:34.036691','2026-09-23 16:24:34.036691'),(427,2,9,3,'2026-09-23 16:24:34.039805','2026-09-23 16:24:34.039805'),(428,2,10,3,'2026-09-23 16:24:34.043017','2026-09-23 16:24:34.043017'),(429,2,11,3,'2026-09-23 16:24:34.046707','2026-09-23 16:24:34.046707'),(430,2,12,3,'2026-09-23 16:24:34.050492','2026-09-23 16:24:34.050492'),(431,2,13,3,'2026-09-23 16:24:34.055365','2026-09-23 16:24:34.055365'),(432,2,14,3,'2026-09-23 16:24:34.058460','2026-09-23 16:24:34.058460'),(433,2,15,3,'2026-09-23 16:24:34.061790','2026-09-23 16:24:34.061790'),(434,2,16,3,'2026-09-23 16:24:34.065309','2026-09-23 16:24:34.065309'),(435,2,17,3,'2026-09-23 16:24:34.068457','2026-09-23 16:24:34.068457'),(436,2,18,3,'2026-09-23 16:24:34.071931','2026-09-23 16:24:34.071931'),(437,2,19,3,'2026-09-23 16:24:34.075074','2026-09-23 16:24:34.075074'),(438,3,1,3,'2026-09-23 16:24:34.078079','2026-09-23 16:24:34.078079'),(439,3,2,3,'2026-09-23 16:24:34.081076','2026-09-23 16:24:34.081076'),(440,3,3,3,'2026-09-23 16:24:34.083951','2026-09-23 16:24:34.083951'),(441,3,4,3,'2026-09-23 16:24:34.086774','2026-09-23 16:24:34.086774'),(442,3,5,3,'2026-09-23 16:24:34.089671','2026-09-23 16:24:34.089671'),(443,3,6,3,'2026-09-23 16:24:34.092825','2026-09-23 16:24:34.092825'),(444,3,7,3,'2026-09-23 16:24:34.095852','2026-09-23 16:24:34.095852'),(445,3,8,3,'2026-09-23 16:24:34.098769','2026-09-23 16:24:34.098769'),(446,3,9,3,'2026-09-23 16:24:34.101649','2026-09-23 16:24:34.101649'),(447,3,10,3,'2026-09-23 16:24:34.104454','2026-09-23 16:24:34.104454'),(448,3,11,3,'2026-09-23 16:24:34.107149','2026-09-23 16:24:34.107149'),(449,3,12,3,'2026-09-23 16:24:34.109977','2026-09-23 16:24:34.109977'),(450,3,13,3,'2026-09-23 16:24:34.113685','2026-09-23 16:24:34.113685'),(451,3,14,3,'2026-09-23 16:24:34.116195','2026-09-23 16:24:34.116195'),(452,3,15,3,'2026-09-23 16:24:34.119852','2026-09-23 16:24:34.119852'),(453,3,16,3,'2026-09-23 16:24:34.123382','2026-09-23 16:24:34.123382'),(454,3,17,3,'2026-09-23 16:24:34.126236','2026-09-23 16:24:34.126236'),(455,3,18,3,'2026-09-23 16:24:34.129367','2026-09-23 16:24:34.129367'),(456,3,19,3,'2026-09-23 16:24:34.132027','2026-09-23 16:24:34.132027'),(457,4,1,3,'2026-09-23 16:24:34.134673','2026-09-23 16:24:34.134673'),(458,4,2,3,'2026-09-23 16:24:34.137391','2026-09-23 16:24:34.137391'),(459,4,3,3,'2026-09-23 16:24:34.140392','2026-09-23 16:24:34.140392'),(460,4,4,3,'2026-09-23 16:24:34.143081','2026-09-23 16:24:34.143081'),(461,4,5,3,'2026-09-23 16:24:34.146197','2026-09-23 16:24:34.146197'),(462,4,6,3,'2026-09-23 16:24:34.150586','2026-09-23 16:24:34.150586'),(463,4,7,3,'2026-09-23 16:24:34.164123','2026-09-23 16:24:34.164123'),(464,4,8,3,'2026-09-23 16:24:34.166966','2026-09-23 16:24:34.166966'),(465,4,9,3,'2026-09-23 16:24:34.170869','2026-09-23 16:24:34.170869'),(466,4,10,3,'2026-09-23 16:24:34.173773','2026-09-23 16:24:34.173773'),(467,4,11,3,'2026-09-23 16:24:34.176413','2026-09-23 16:24:34.176413'),(468,4,12,3,'2026-09-23 16:24:34.179091','2026-09-23 16:24:34.179091'),(469,4,13,3,'2026-09-23 16:24:34.181846','2026-09-23 16:24:34.181846'),(470,4,14,3,'2026-09-23 16:24:34.184489','2026-09-23 16:24:34.184489'),(471,4,15,3,'2026-09-23 16:24:34.187091','2026-09-23 16:24:34.187091'),(472,4,16,3,'2026-09-23 16:24:34.189634','2026-09-23 16:24:34.189634'),(473,4,17,3,'2026-09-23 16:24:34.192011','2026-09-23 16:24:34.192011'),(474,4,18,3,'2026-09-23 16:24:34.194408','2026-09-23 16:24:34.194408'),(475,4,19,3,'2026-09-23 16:24:34.197112','2026-09-23 16:24:34.197112'),(476,4,20,3,'2026-09-23 16:24:34.199662','2026-09-23 16:24:34.199662'),(477,5,1,3,'2026-09-23 16:24:34.201721','2026-09-23 16:24:34.201721'),(478,5,2,3,'2026-09-23 16:24:34.204088','2026-09-23 16:24:34.204088'),(479,5,3,3,'2026-09-23 16:24:34.206130','2026-09-23 16:24:34.206130'),(480,5,4,3,'2026-09-23 16:24:34.208130','2026-09-23 16:24:34.208130'),(481,5,5,3,'2026-09-23 16:24:34.210154','2026-09-23 16:24:34.210154'),(482,5,6,3,'2026-09-23 16:24:34.212290','2026-09-23 16:24:34.212290'),(483,5,7,3,'2026-09-23 16:24:34.214431','2026-09-23 16:24:34.214431'),(484,5,8,3,'2026-09-23 16:24:34.216686','2026-09-23 16:24:34.216686'),(485,5,9,3,'2026-09-23 16:24:34.219883','2026-09-23 16:24:34.219883'),(486,5,10,3,'2026-09-23 16:24:34.223127','2026-09-23 16:24:34.223127'),(487,5,11,3,'2026-09-23 16:24:34.227863','2026-09-23 16:24:34.227863'),(488,5,12,3,'2026-09-23 16:24:34.233650','2026-09-23 16:24:34.233650'),(489,5,13,3,'2026-09-23 16:24:34.246215','2026-09-23 16:24:34.246215'),(490,5,14,3,'2026-09-23 16:24:34.248777','2026-09-23 16:24:34.248777'),(491,5,15,3,'2026-09-23 16:24:34.250915','2026-09-23 16:24:34.250915'),(492,5,16,3,'2026-09-23 16:24:34.253575','2026-09-23 16:24:34.253575'),(493,5,17,3,'2026-09-23 16:24:34.256073','2026-09-23 16:24:34.256073'),(494,5,18,3,'2026-09-23 16:24:34.258918','2026-09-23 16:24:34.258918'),(495,5,19,3,'2026-09-23 16:24:34.261723','2026-09-23 16:24:34.261723'),(496,5,20,3,'2026-09-23 16:24:34.264237','2026-09-23 16:24:34.264237'),(497,6,1,3,'2026-09-23 16:24:34.266586','2026-09-23 16:24:34.266586'),(498,6,2,3,'2026-09-23 16:24:34.269548','2026-09-23 16:24:34.269548'),(499,6,3,3,'2026-09-23 16:24:34.272240','2026-09-23 16:24:34.272240'),(500,6,4,3,'2026-09-23 16:24:34.274976','2026-09-23 16:24:34.274976'),(501,6,5,3,'2026-09-23 16:24:34.277708','2026-09-23 16:24:34.277708'),(502,6,6,3,'2026-09-23 16:24:34.280113','2026-09-23 16:24:34.280113'),(503,6,7,3,'2026-09-23 16:24:34.282876','2026-09-23 16:24:34.282876'),(504,6,8,3,'2026-09-23 16:24:34.285826','2026-09-23 16:24:34.285826'),(505,6,9,3,'2026-09-23 16:24:34.288506','2026-09-23 16:24:34.288506'),(506,6,10,3,'2026-09-23 16:24:34.291411','2026-09-23 16:24:34.291411'),(507,6,11,3,'2026-09-23 16:24:34.294193','2026-09-23 16:24:34.294193'),(508,6,12,3,'2026-09-23 16:24:34.296839','2026-09-23 16:24:34.296839'),(509,6,13,3,'2026-09-23 16:24:34.299790','2026-09-23 16:24:34.299790'),(510,6,14,3,'2026-09-23 16:24:34.303436','2026-09-23 16:24:34.303436'),(511,6,15,3,'2026-09-23 16:24:34.306363','2026-09-23 16:24:34.306363'),(512,6,16,3,'2026-09-23 16:24:34.309058','2026-09-23 16:24:34.309058'),(513,6,17,3,'2026-09-23 16:24:34.311750','2026-09-23 16:24:34.311750'),(514,6,18,3,'2026-09-23 16:24:34.314596','2026-09-23 16:24:34.314596'),(515,6,19,3,'2026-09-23 16:24:34.317412','2026-09-23 16:24:34.317412'),(516,6,20,3,'2026-09-23 16:24:34.320039','2026-09-23 16:24:34.320039'),(517,7,1,3,'2026-09-23 16:24:34.322689','2026-09-23 16:24:34.322689'),(518,7,2,3,'2026-09-23 16:24:34.325345','2026-09-23 16:24:34.325345'),(519,7,3,3,'2026-09-23 16:24:34.327963','2026-09-23 16:24:34.327963'),(520,7,4,3,'2026-09-23 16:24:34.330413','2026-09-23 16:24:34.330413'),(521,7,5,3,'2026-09-23 16:24:34.333164','2026-09-23 16:24:34.333164'),(522,7,6,3,'2026-09-23 16:24:34.335907','2026-09-23 16:24:34.335907'),(523,7,7,3,'2026-09-23 16:24:34.338441','2026-09-23 16:24:34.338441'),(524,7,8,3,'2026-09-23 16:24:34.341039','2026-09-23 16:24:34.341039'),(525,7,9,3,'2026-09-23 16:24:34.343855','2026-09-23 16:24:34.343855'),(526,7,10,3,'2026-09-23 16:24:34.346394','2026-09-23 16:24:34.346394'),(527,7,11,3,'2026-09-23 16:24:34.349066','2026-09-23 16:24:34.349066'),(528,7,12,3,'2026-09-23 16:24:34.351593','2026-09-23 16:24:34.351593'),(529,7,13,3,'2026-09-23 16:24:34.354061','2026-09-23 16:24:34.354061'),(530,7,14,3,'2026-09-23 16:24:34.356466','2026-09-23 16:24:34.356466'),(531,7,15,3,'2026-09-23 16:24:34.358885','2026-09-23 16:24:34.358885'),(532,7,16,3,'2026-09-23 16:24:34.361523','2026-09-23 16:24:34.361523'),(533,7,17,3,'2026-09-23 16:24:34.364192','2026-09-23 16:24:34.364192'),(534,7,18,3,'2026-09-23 16:24:34.366531','2026-09-23 16:24:34.366531'),(535,7,19,3,'2026-09-23 16:24:34.368748','2026-09-23 16:24:34.368748'),(536,7,20,3,'2026-09-23 16:24:34.370789','2026-09-23 16:24:34.370789'),(537,8,1,3,'2026-09-23 16:24:34.373153','2026-09-23 16:24:34.373153'),(538,8,2,3,'2026-09-23 16:24:34.375321','2026-09-23 16:24:34.375321'),(539,8,3,3,'2026-09-23 16:24:34.377113','2026-09-23 16:24:34.377113'),(540,8,4,3,'2026-09-23 16:24:34.378880','2026-09-23 16:24:34.378880'),(541,8,5,3,'2026-09-23 16:24:34.380782','2026-09-23 16:24:34.380782'),(542,8,6,3,'2026-09-23 16:24:34.382636','2026-09-23 16:24:34.382636'),(543,8,7,3,'2026-09-23 16:24:34.384857','2026-09-23 16:24:34.384857'),(544,8,8,3,'2026-09-23 16:24:34.386841','2026-09-23 16:24:34.386841'),(545,8,9,3,'2026-09-23 16:24:34.389092','2026-09-23 16:24:34.389092'),(546,8,10,3,'2026-09-23 16:24:34.391542','2026-09-23 16:24:34.391542'),(547,8,11,3,'2026-09-23 16:24:34.393659','2026-09-23 16:24:34.393659'),(548,8,12,3,'2026-09-23 16:24:34.395821','2026-09-23 16:24:34.395821'),(549,8,13,3,'2026-09-23 16:24:34.398019','2026-09-23 16:24:34.398019'),(550,8,14,3,'2026-09-23 16:24:34.400087','2026-09-23 16:24:34.400087'),(551,8,15,3,'2026-09-23 16:24:34.402158','2026-09-23 16:24:34.402158'),(552,8,16,3,'2026-09-23 16:24:34.412625','2026-09-23 16:24:34.412625'),(553,8,17,3,'2026-09-23 16:24:34.415455','2026-09-23 16:24:34.415455'),(554,8,18,3,'2026-09-23 16:24:34.418762','2026-09-23 16:24:34.418762'),(555,8,19,3,'2026-09-23 16:24:34.421941','2026-09-23 16:24:34.421941'),(556,8,20,3,'2026-09-23 16:24:34.425446','2026-09-23 16:24:34.425446'),(557,8,21,3,'2026-09-23 16:24:34.428585','2026-09-23 16:24:34.428585'),(558,9,1,3,'2026-09-23 16:24:34.431013','2026-09-23 16:24:34.431013'),(559,9,2,3,'2026-09-23 16:24:34.433670','2026-09-23 16:24:34.433670'),(560,9,3,3,'2026-09-23 16:24:34.436479','2026-09-23 16:24:34.436479'),(561,9,4,3,'2026-09-23 16:24:34.438681','2026-09-23 16:24:34.438681'),(562,9,5,3,'2026-09-23 16:24:34.441439','2026-09-23 16:24:34.441439'),(563,9,6,3,'2026-09-23 16:24:34.444167','2026-09-23 16:24:34.444167'),(564,9,7,3,'2026-09-23 16:24:34.447000','2026-09-23 16:24:34.447000'),(565,9,8,3,'2026-09-23 16:24:34.449654','2026-09-23 16:24:34.449654'),(566,9,9,3,'2026-09-23 16:24:34.452620','2026-09-23 16:24:34.452620'),(567,9,10,3,'2026-09-23 16:24:34.454926','2026-09-23 16:24:34.454926'),(568,9,11,3,'2026-09-23 16:24:34.457379','2026-09-23 16:24:34.457379'),(569,9,12,3,'2026-09-23 16:24:34.459906','2026-09-23 16:24:34.459906'),(570,9,13,3,'2026-09-23 16:24:34.462203','2026-09-23 16:24:34.462203'),(571,9,14,3,'2026-09-23 16:24:34.464518','2026-09-23 16:24:34.464518'),(572,9,15,3,'2026-09-23 16:24:34.466877','2026-09-23 16:24:34.466877'),(573,9,16,3,'2026-09-23 16:24:34.469141','2026-09-23 16:24:34.469141'),(574,9,17,3,'2026-09-23 16:24:34.471389','2026-09-23 16:24:34.471389'),(575,9,18,3,'2026-09-23 16:24:34.474165','2026-09-23 16:24:34.474165'),(576,9,19,3,'2026-09-23 16:24:34.476630','2026-09-23 16:24:34.476630'),(577,9,20,3,'2026-09-23 16:24:34.479046','2026-09-23 16:24:34.479046'),(578,9,21,3,'2026-09-23 16:24:34.481478','2026-09-23 16:24:34.481478'),(579,10,1,3,'2026-09-23 16:24:34.483872','2026-09-23 16:24:34.483872'),(580,10,2,3,'2026-09-23 16:24:34.486214','2026-09-23 16:24:34.486214'),(581,10,3,3,'2026-09-23 16:24:34.489040','2026-09-23 16:24:34.489040'),(582,10,4,3,'2026-09-23 16:24:34.491838','2026-09-23 16:24:34.491838'),(583,10,5,3,'2026-09-23 16:24:34.494512','2026-09-23 16:24:34.494512'),(584,10,6,3,'2026-09-23 16:24:34.497206','2026-09-23 16:24:34.497206'),(585,10,7,3,'2026-09-23 16:24:34.499779','2026-09-23 16:24:34.499779'),(586,10,8,3,'2026-09-23 16:24:34.502271','2026-09-23 16:24:34.502271'),(587,10,9,3,'2026-09-23 16:24:34.505184','2026-09-23 16:24:34.505184'),(588,10,10,3,'2026-09-23 16:24:34.508036','2026-09-23 16:24:34.508036'),(589,10,11,3,'2026-09-23 16:24:34.510581','2026-09-23 16:24:34.510581'),(590,10,12,3,'2026-09-23 16:24:34.513238','2026-09-23 16:24:34.513238'),(591,10,13,3,'2026-09-23 16:24:34.515809','2026-09-23 16:24:34.515809'),(592,10,14,3,'2026-09-23 16:24:34.518298','2026-09-23 16:24:34.518298'),(593,10,15,3,'2026-09-23 16:24:34.520737','2026-09-23 16:24:34.520737'),(594,10,16,3,'2026-09-23 16:24:34.523087','2026-09-23 16:24:34.523087'),(595,10,17,3,'2026-09-23 16:24:34.525446','2026-09-23 16:24:34.525446'),(596,10,18,3,'2026-09-23 16:24:34.527834','2026-09-23 16:24:34.527834'),(597,10,19,3,'2026-09-23 16:24:34.530117','2026-09-23 16:24:34.530117'),(598,10,20,3,'2026-09-23 16:24:34.532345','2026-09-23 16:24:34.532345'),(599,10,21,3,'2026-09-23 16:24:34.534635','2026-09-23 16:24:34.534635'),(600,10,22,3,'2026-09-23 16:24:34.537153','2026-09-23 16:24:34.537153'),(601,1,1,4,'2026-09-23 16:24:34.543596','2026-09-23 16:24:34.543596'),(602,1,2,4,'2026-09-23 16:24:34.546406','2026-09-23 16:24:34.546406'),(603,1,3,4,'2026-09-23 16:24:34.549107','2026-09-23 16:24:34.549107'),(604,1,4,4,'2026-09-23 16:24:34.551935','2026-09-23 16:24:34.551935'),(605,1,5,4,'2026-09-23 16:24:34.554643','2026-09-23 16:24:34.554643'),(606,1,6,4,'2026-09-23 16:24:34.557346','2026-09-23 16:24:34.557346'),(607,1,7,4,'2026-09-23 16:24:34.559991','2026-09-23 16:24:34.559991'),(608,1,8,4,'2026-09-23 16:24:34.562412','2026-09-23 16:24:34.562412'),(609,1,9,4,'2026-09-23 16:24:34.565012','2026-09-23 16:24:34.565012'),(610,1,10,4,'2026-09-23 16:24:34.567555','2026-09-23 16:24:34.567555'),(611,1,11,4,'2026-09-23 16:24:34.570007','2026-09-23 16:24:34.570007'),(612,1,12,4,'2026-09-23 16:24:34.572844','2026-09-23 16:24:34.572844'),(613,1,13,4,'2026-09-23 16:24:34.575429','2026-09-23 16:24:34.575429'),(614,1,14,4,'2026-09-23 16:24:34.577991','2026-09-23 16:24:34.577991'),(615,1,15,4,'2026-09-23 16:24:34.580383','2026-09-23 16:24:34.580383'),(616,1,16,4,'2026-09-23 16:24:34.583079','2026-09-23 16:24:34.583079'),(617,1,17,4,'2026-09-23 16:24:34.585755','2026-09-23 16:24:34.585755'),(618,1,18,4,'2026-09-23 16:24:34.588184','2026-09-23 16:24:34.588184'),(619,1,19,4,'2026-09-23 16:24:34.590629','2026-09-23 16:24:34.590629'),(620,1,20,4,'2026-09-23 16:24:34.593193','2026-09-23 16:24:34.593193'),(621,1,21,4,'2026-09-23 16:24:34.595786','2026-09-23 16:24:34.595786'),(622,1,22,4,'2026-09-23 16:24:34.598464','2026-09-23 16:24:34.598464'),(623,1,23,4,'2026-09-23 16:24:34.601404','2026-09-23 16:24:34.601404'),(624,1,24,4,'2026-09-23 16:24:34.604036','2026-09-23 16:24:34.604036'),(625,1,25,4,'2026-09-23 16:24:34.606688','2026-09-23 16:24:34.606688'),(626,2,1,4,'2026-09-23 16:24:34.609415','2026-09-23 16:24:34.609415'),(627,2,2,4,'2026-09-23 16:24:34.612023','2026-09-23 16:24:34.612023'),(628,2,3,4,'2026-09-23 16:24:34.614459','2026-09-23 16:24:34.614459'),(629,2,4,4,'2026-09-23 16:24:34.617244','2026-09-23 16:24:34.617244'),(630,2,5,4,'2026-09-23 16:24:34.620279','2026-09-23 16:24:34.620279'),(631,2,6,4,'2026-09-23 16:24:34.623352','2026-09-23 16:24:34.623352'),(632,2,7,4,'2026-09-23 16:24:34.626180','2026-09-23 16:24:34.626180'),(633,2,8,4,'2026-09-23 16:24:34.630044','2026-09-23 16:24:34.630044'),(634,2,9,4,'2026-09-23 16:24:34.632965','2026-09-23 16:24:34.632965'),(635,2,10,4,'2026-09-23 16:24:34.635807','2026-09-23 16:24:34.635807'),(636,2,11,4,'2026-09-23 16:24:34.638679','2026-09-23 16:24:34.638679'),(637,2,12,4,'2026-09-23 16:24:34.642064','2026-09-23 16:24:34.642064'),(638,2,13,4,'2026-09-23 16:24:34.644902','2026-09-23 16:24:34.644902'),(639,2,14,4,'2026-09-23 16:24:34.648040','2026-09-23 16:24:34.648040'),(640,2,15,4,'2026-09-23 16:24:34.651062','2026-09-23 16:24:34.651062'),(641,2,16,4,'2026-09-23 16:24:34.653842','2026-09-23 16:24:34.653842'),(642,2,17,4,'2026-09-23 16:24:34.656395','2026-09-23 16:24:34.656395'),(643,2,18,4,'2026-09-23 16:24:34.658791','2026-09-23 16:24:34.658791'),(644,2,19,4,'2026-09-23 16:24:34.661337','2026-09-23 16:24:34.661337'),(645,2,20,4,'2026-09-23 16:24:34.663940','2026-09-23 16:24:34.663940'),(646,2,21,4,'2026-09-23 16:24:34.666478','2026-09-23 16:24:34.666478'),(647,2,22,4,'2026-09-23 16:24:34.668958','2026-09-23 16:24:34.668958'),(648,2,23,4,'2026-09-23 16:24:34.671659','2026-09-23 16:24:34.671659'),(649,2,24,4,'2026-09-23 16:24:34.674235','2026-09-23 16:24:34.674235'),(650,3,1,4,'2026-09-23 16:24:34.676900','2026-09-23 16:24:34.676900'),(651,3,2,4,'2026-09-23 16:24:34.679485','2026-09-23 16:24:34.679485'),(652,3,3,4,'2026-09-23 16:24:34.687021','2026-09-23 16:24:34.687021'),(653,3,4,4,'2026-09-23 16:24:34.690945','2026-09-23 16:24:34.690945'),(654,3,5,4,'2026-09-23 16:24:34.694085','2026-09-23 16:24:34.694085'),(655,3,6,4,'2026-09-23 16:24:34.697362','2026-09-23 16:24:34.697362'),(656,3,7,4,'2026-09-23 16:24:34.700393','2026-09-23 16:24:34.700393'),(657,3,8,4,'2026-09-23 16:24:34.707630','2026-09-23 16:24:34.707630'),(658,3,9,4,'2026-09-23 16:24:34.711363','2026-09-23 16:24:34.711363'),(659,3,10,4,'2026-09-23 16:24:34.715910','2026-09-23 16:24:34.715910'),(660,3,11,4,'2026-09-23 16:24:34.719052','2026-09-23 16:24:34.719052'),(661,3,12,4,'2026-09-23 16:24:34.721606','2026-09-23 16:24:34.721606'),(662,3,13,4,'2026-09-23 16:24:34.725085','2026-09-23 16:24:34.725085'),(663,3,14,4,'2026-09-23 16:24:34.728505','2026-09-23 16:24:34.728505'),(664,3,15,4,'2026-09-23 16:24:34.731298','2026-09-23 16:24:34.731298'),(665,3,16,4,'2026-09-23 16:24:34.743818','2026-09-23 16:24:34.743818'),(666,3,17,4,'2026-09-23 16:24:34.746808','2026-09-23 16:24:34.746808'),(667,3,18,4,'2026-09-23 16:24:34.753442','2026-09-23 16:24:34.753442'),(668,3,19,4,'2026-09-23 16:24:34.763365','2026-09-23 16:24:34.763365'),(669,3,20,4,'2026-09-23 16:24:34.771682','2026-09-23 16:24:34.771682'),(670,3,21,4,'2026-09-23 16:24:34.774545','2026-09-23 16:24:34.774545'),(671,3,22,4,'2026-09-23 16:24:34.783842','2026-09-23 16:24:34.783842'),(672,3,23,4,'2026-09-23 16:24:34.786665','2026-09-23 16:24:34.786665'),(673,4,1,4,'2026-09-23 16:24:34.789344','2026-09-23 16:24:34.789344'),(674,4,2,4,'2026-09-23 16:24:34.792169','2026-09-23 16:24:34.792169'),(675,4,3,4,'2026-09-23 16:24:34.805388','2026-09-23 16:24:34.805388'),(676,4,4,4,'2026-09-23 16:24:34.808261','2026-09-23 16:24:34.808261'),(677,4,5,4,'2026-09-23 16:24:34.810963','2026-09-23 16:24:34.810963'),(678,4,6,4,'2026-09-23 16:24:34.813566','2026-09-23 16:24:34.813566'),(679,4,7,4,'2026-09-23 16:24:34.816432','2026-09-23 16:24:34.816432'),(680,4,8,4,'2026-09-23 16:24:34.823854','2026-09-23 16:24:34.823854'),(681,4,9,4,'2026-09-23 16:24:34.826678','2026-09-23 16:24:34.826678'),(682,4,10,4,'2026-09-23 16:24:34.829230','2026-09-23 16:24:34.829230'),(683,4,11,4,'2026-09-23 16:24:34.833571','2026-09-23 16:24:34.833571'),(684,4,12,4,'2026-09-23 16:24:34.843752','2026-09-23 16:24:34.843752'),(685,4,13,4,'2026-09-23 16:24:34.846484','2026-09-23 16:24:34.846484'),(686,4,14,4,'2026-09-23 16:24:34.849151','2026-09-23 16:24:34.849151'),(687,4,15,4,'2026-09-23 16:24:34.851584','2026-09-23 16:24:34.851584'),(688,4,16,4,'2026-09-23 16:24:34.854064','2026-09-23 16:24:34.854064'),(689,4,17,4,'2026-09-23 16:24:34.860985','2026-09-23 16:24:34.860985'),(690,4,18,4,'2026-09-23 16:24:34.863773','2026-09-23 16:24:34.863773'),(691,4,19,4,'2026-09-23 16:24:34.873675','2026-09-23 16:24:34.873675'),(692,4,20,4,'2026-09-23 16:24:34.876478','2026-09-23 16:24:34.876478'),(693,4,21,4,'2026-09-23 16:24:34.878785','2026-09-23 16:24:34.878785'),(694,4,22,4,'2026-09-23 16:24:34.881151','2026-09-23 16:24:34.881151'),(695,5,1,4,'2026-09-23 16:24:34.883453','2026-09-23 16:24:34.883453'),(696,5,2,4,'2026-09-23 16:24:34.893667','2026-09-23 16:24:34.893667'),(697,5,3,4,'2026-09-23 16:24:34.896338','2026-09-23 16:24:34.896338'),(698,5,4,4,'2026-09-23 16:24:34.898751','2026-09-23 16:24:34.898751'),(699,5,5,4,'2026-09-23 16:24:34.901236','2026-09-23 16:24:34.901236'),(700,5,6,4,'2026-09-23 16:24:34.903751','2026-09-23 16:24:34.903751'),(701,5,7,4,'2026-09-23 16:24:34.911350','2026-09-23 16:24:34.911350'),(702,5,8,4,'2026-09-23 16:24:34.914115','2026-09-23 16:24:34.914115'),(703,5,9,4,'2026-09-23 16:24:34.923757','2026-09-23 16:24:34.923757'),(704,5,10,4,'2026-09-23 16:24:34.926537','2026-09-23 16:24:34.926537'),(705,5,11,4,'2026-09-23 16:24:34.929092','2026-09-23 16:24:34.929092'),(706,5,12,4,'2026-09-23 16:24:34.931478','2026-09-23 16:24:34.931478'),(707,5,13,4,'2026-09-23 16:24:34.941450','2026-09-23 16:24:34.941450'),(708,5,14,4,'2026-09-23 16:24:34.944184','2026-09-23 16:24:34.944184'),(709,5,15,4,'2026-09-23 16:24:34.946760','2026-09-23 16:24:34.946760'),(710,5,16,4,'2026-09-23 16:24:34.949253','2026-09-23 16:24:34.949253'),(711,5,17,4,'2026-09-23 16:24:34.951549','2026-09-23 16:24:34.951549'),(712,5,18,4,'2026-09-23 16:24:34.961862','2026-09-23 16:24:34.961862'),(713,5,19,4,'2026-09-23 16:24:34.964650','2026-09-23 16:24:34.964650'),(714,5,20,4,'2026-09-23 16:24:34.967132','2026-09-23 16:24:34.967132'),(715,5,21,4,'2026-09-23 16:24:34.969708','2026-09-23 16:24:34.969708'),(716,6,1,4,'2026-09-23 16:24:34.973699','2026-09-23 16:24:34.973699'),(717,6,2,4,'2026-09-23 16:24:34.981035','2026-09-23 16:24:34.981035'),(718,6,3,4,'2026-09-23 16:24:34.983577','2026-09-23 16:24:34.983577'),(719,6,4,4,'2026-09-23 16:24:34.993688','2026-09-23 16:24:34.993688'),(720,6,5,4,'2026-09-23 16:24:34.996440','2026-09-23 16:24:34.996440'),(721,6,6,4,'2026-09-23 16:24:34.998904','2026-09-23 16:24:34.998904'),(722,6,7,4,'2026-09-23 16:24:35.001430','2026-09-23 16:24:35.001430'),(723,6,8,4,'2026-09-23 16:24:35.005365','2026-09-23 16:24:35.005365'),(724,6,9,4,'2026-09-23 16:24:35.012090','2026-09-23 16:24:35.012090'),(725,6,10,4,'2026-09-23 16:24:35.014965','2026-09-23 16:24:35.014965'),(726,6,11,4,'2026-09-23 16:24:35.023100','2026-09-23 16:24:35.023100'),(727,6,12,4,'2026-09-23 16:24:35.025826','2026-09-23 16:24:35.025826'),(728,6,13,4,'2026-09-23 16:24:35.028422','2026-09-23 16:24:35.028422'),(729,6,14,4,'2026-09-23 16:24:35.030838','2026-09-23 16:24:35.030838'),(730,6,15,4,'2026-09-23 16:24:35.043860','2026-09-23 16:24:35.043860'),(731,6,16,4,'2026-09-23 16:24:35.046656','2026-09-23 16:24:35.046656'),(732,6,17,4,'2026-09-23 16:24:35.049159','2026-09-23 16:24:35.049159'),(733,6,18,4,'2026-09-23 16:24:35.051464','2026-09-23 16:24:35.051464'),(734,6,19,4,'2026-09-23 16:24:35.054143','2026-09-23 16:24:35.054143'),(735,7,1,4,'2026-09-23 16:24:35.061805','2026-09-23 16:24:35.061805'),(736,7,2,4,'2026-09-23 16:24:35.064687','2026-09-23 16:24:35.064687'),(737,7,3,4,'2026-09-23 16:24:35.067315','2026-09-23 16:24:35.067315'),(738,7,4,4,'2026-09-23 16:24:35.072209','2026-09-23 16:24:35.072209'),(739,7,5,4,'2026-09-23 16:24:35.076639','2026-09-23 16:24:35.076639'),(740,7,6,4,'2026-09-23 16:24:35.083738','2026-09-23 16:24:35.083738'),(741,7,7,4,'2026-09-23 16:24:35.086538','2026-09-23 16:24:35.086538'),(742,7,8,4,'2026-09-23 16:24:35.093634','2026-09-23 16:24:35.093634'),(743,7,9,4,'2026-09-23 16:24:35.096533','2026-09-23 16:24:35.096533'),(744,7,10,4,'2026-09-23 16:24:35.099135','2026-09-23 16:24:35.099135'),(745,7,11,4,'2026-09-23 16:24:35.103743','2026-09-23 16:24:35.103743'),(746,7,12,4,'2026-09-23 16:24:35.110848','2026-09-23 16:24:35.110848'),(747,7,13,4,'2026-09-23 16:24:35.113557','2026-09-23 16:24:35.113557'),(748,7,14,4,'2026-09-23 16:24:35.123752','2026-09-23 16:24:35.123752'),(749,7,15,4,'2026-09-23 16:24:35.126598','2026-09-23 16:24:35.126598'),(750,7,16,4,'2026-09-23 16:24:35.129425','2026-09-23 16:24:35.129425'),(751,7,17,4,'2026-09-23 16:24:35.131783','2026-09-23 16:24:35.131783'),(752,7,18,4,'2026-09-23 16:24:35.134050','2026-09-23 16:24:35.134050'),(753,8,1,4,'2026-09-23 16:24:35.143906','2026-09-23 16:24:35.143906'),(754,8,2,4,'2026-09-23 16:24:35.146785','2026-09-23 16:24:35.146785'),(755,8,3,4,'2026-09-23 16:24:35.149401','2026-09-23 16:24:35.149401'),(756,8,4,4,'2026-09-23 16:24:35.162056','2026-09-23 16:24:35.162056'),(757,8,5,4,'2026-09-23 16:24:35.165191','2026-09-23 16:24:35.165191'),(758,8,6,4,'2026-09-23 16:24:35.167784','2026-09-23 16:24:35.167784'),(759,8,7,4,'2026-09-23 16:24:35.170260','2026-09-23 16:24:35.170260'),(760,8,8,4,'2026-09-23 16:24:35.172639','2026-09-23 16:24:35.172639'),(761,8,9,4,'2026-09-23 16:24:35.175541','2026-09-23 16:24:35.175541'),(762,8,10,4,'2026-09-23 16:24:35.183659','2026-09-23 16:24:35.183659'),(763,8,11,4,'2026-09-23 16:24:35.186489','2026-09-23 16:24:35.186489'),(764,8,12,4,'2026-09-23 16:24:35.193802','2026-09-23 16:24:35.193802'),(765,8,13,4,'2026-09-23 16:24:35.204281','2026-09-23 16:24:35.204281'),(766,8,14,4,'2026-09-23 16:24:35.213411','2026-09-23 16:24:35.213411'),(767,8,15,4,'2026-09-23 16:24:35.216063','2026-09-23 16:24:35.216063'),(768,8,16,4,'2026-09-23 16:24:35.218713','2026-09-23 16:24:35.218713'),(769,8,17,4,'2026-09-23 16:24:35.223430','2026-09-23 16:24:35.223430'),(770,9,1,4,'2026-09-23 16:24:35.226065','2026-09-23 16:24:35.226065'),(771,9,2,4,'2026-09-23 16:24:35.228803','2026-09-23 16:24:35.228803'),(772,9,3,4,'2026-09-23 16:24:35.231472','2026-09-23 16:24:35.231472'),(773,9,4,4,'2026-09-23 16:24:35.235182','2026-09-23 16:24:35.235182'),(774,9,5,4,'2026-09-23 16:24:35.237811','2026-09-23 16:24:35.237811'),(775,9,6,4,'2026-09-23 16:24:35.240230','2026-09-23 16:24:35.240230'),(776,9,7,4,'2026-09-23 16:24:35.242855','2026-09-23 16:24:35.242855'),(777,9,8,4,'2026-09-23 16:24:35.245480','2026-09-23 16:24:35.245480'),(778,9,9,4,'2026-09-23 16:24:35.248262','2026-09-23 16:24:35.248262'),(779,9,10,4,'2026-09-23 16:24:35.251410','2026-09-23 16:24:35.251410'),(780,9,11,4,'2026-09-23 16:24:35.254404','2026-09-23 16:24:35.254404'),(781,9,12,4,'2026-09-23 16:24:35.263437','2026-09-23 16:24:35.263437'),(782,9,13,4,'2026-09-23 16:24:35.266199','2026-09-23 16:24:35.266199'),(783,9,14,4,'2026-09-23 16:24:35.268742','2026-09-23 16:24:35.268742'),(784,9,15,4,'2026-09-23 16:24:35.271251','2026-09-23 16:24:35.271251'),(785,9,16,4,'2026-09-23 16:24:35.274835','2026-09-23 16:24:35.274835'),(786,10,1,4,'2026-09-23 16:24:35.285430','2026-09-23 16:24:35.285430'),(787,10,2,4,'2026-09-23 16:24:35.287949','2026-09-23 16:24:35.287949'),(788,10,3,4,'2026-09-23 16:24:35.290322','2026-09-23 16:24:35.290322'),(789,10,4,4,'2026-09-23 16:24:35.292591','2026-09-23 16:24:35.292591'),(790,10,5,4,'2026-09-23 16:24:35.294850','2026-09-23 16:24:35.294850'),(791,10,6,4,'2026-09-23 16:24:35.300481','2026-09-23 16:24:35.300481'),(792,10,7,4,'2026-09-23 16:24:35.303050','2026-09-23 16:24:35.303050'),(793,10,8,4,'2026-09-23 16:24:35.308601','2026-09-23 16:24:35.308601'),(794,10,9,4,'2026-09-23 16:24:35.314951','2026-09-23 16:24:35.314951'),(795,10,10,4,'2026-09-23 16:24:35.317403','2026-09-23 16:24:35.317403'),(796,10,11,4,'2026-09-23 16:24:35.323748','2026-09-23 16:24:35.323748'),(797,10,12,4,'2026-09-23 16:24:35.326761','2026-09-23 16:24:35.326761'),(798,10,13,4,'2026-09-23 16:24:35.333644','2026-09-23 16:24:35.333644'),(799,10,14,4,'2026-09-23 16:24:35.336426','2026-09-23 16:24:35.336426'),(800,10,15,4,'2026-09-23 16:24:35.339020','2026-09-23 16:24:35.339020'),(801,1,1,5,'2026-09-23 16:24:35.354247','2026-09-23 16:24:35.354247'),(802,1,2,5,'2026-09-23 16:24:35.356988','2026-09-23 16:24:35.356988'),(803,1,3,5,'2026-09-23 16:24:35.363101','2026-09-23 16:24:35.363101'),(804,1,4,5,'2026-09-23 16:24:35.365724','2026-09-23 16:24:35.365724'),(805,1,5,5,'2026-09-23 16:24:35.373570','2026-09-23 16:24:35.373570'),(806,1,6,5,'2026-09-23 16:24:35.376291','2026-09-23 16:24:35.376291'),(807,1,7,5,'2026-09-23 16:24:35.378839','2026-09-23 16:24:35.378839'),(808,1,8,5,'2026-09-23 16:24:35.383590','2026-09-23 16:24:35.383590'),(809,1,9,5,'2026-09-23 16:24:35.385949','2026-09-23 16:24:35.385949'),(810,1,10,5,'2026-09-23 16:24:35.393668','2026-09-23 16:24:35.393668'),(811,1,11,5,'2026-09-23 16:24:35.396270','2026-09-23 16:24:35.396270'),(812,1,12,5,'2026-09-23 16:24:35.398844','2026-09-23 16:24:35.398844'),(813,1,13,5,'2026-09-23 16:24:35.403608','2026-09-23 16:24:35.403608'),(814,1,14,5,'2026-09-23 16:24:35.406153','2026-09-23 16:24:35.406153'),(815,1,15,5,'2026-09-23 16:24:35.414684','2026-09-23 16:24:35.414684'),(816,1,16,5,'2026-09-23 16:24:35.417268','2026-09-23 16:24:35.417268'),(817,1,17,5,'2026-09-23 16:24:35.419692','2026-09-23 16:24:35.419692'),(818,1,18,5,'2026-09-23 16:24:35.423492','2026-09-23 16:24:35.423492'),(819,1,19,5,'2026-09-23 16:24:35.434900','2026-09-23 16:24:35.434900'),(820,1,20,5,'2026-09-23 16:24:35.437281','2026-09-23 16:24:35.437281'),(821,1,21,5,'2026-09-23 16:24:35.439548','2026-09-23 16:24:35.439548'),(822,1,22,5,'2026-09-23 16:24:35.441715','2026-09-23 16:24:35.441715'),(823,1,23,5,'2026-09-23 16:24:35.443833','2026-09-23 16:24:35.443833'),(824,1,24,5,'2026-09-23 16:24:35.453629','2026-09-23 16:24:35.453629'),(825,1,25,5,'2026-09-23 16:24:35.456208','2026-09-23 16:24:35.456208'),(826,2,1,5,'2026-09-23 16:24:35.458741','2026-09-23 16:24:35.458741'),(827,2,2,5,'2026-09-23 16:24:35.465071','2026-09-23 16:24:35.465071'),(828,2,3,5,'2026-09-23 16:24:35.471103','2026-09-23 16:24:35.471103'),(829,2,4,5,'2026-09-23 16:24:35.473943','2026-09-23 16:24:35.473943'),(830,2,5,5,'2026-09-23 16:24:35.477927','2026-09-23 16:24:35.477927'),(831,2,6,5,'2026-09-23 16:24:35.483572','2026-09-23 16:24:35.483572'),(832,2,7,5,'2026-09-23 16:24:35.487356','2026-09-23 16:24:35.487356'),(833,2,8,5,'2026-09-23 16:24:35.493680','2026-09-23 16:24:35.493680'),(834,2,9,5,'2026-09-23 16:24:35.496508','2026-09-23 16:24:35.496508'),(835,2,10,5,'2026-09-23 16:24:35.503803','2026-09-23 16:24:35.503803'),(836,2,11,5,'2026-09-23 16:24:35.506623','2026-09-23 16:24:35.506623'),(837,2,12,5,'2026-09-23 16:24:35.509182','2026-09-23 16:24:35.509182'),(838,2,13,5,'2026-09-23 16:24:35.513536','2026-09-23 16:24:35.513536'),(839,2,14,5,'2026-09-23 16:24:35.524815','2026-09-23 16:24:35.524815'),(840,2,15,5,'2026-09-23 16:24:35.527272','2026-09-23 16:24:35.527272'),(841,2,16,5,'2026-09-23 16:24:35.529692','2026-09-23 16:24:35.529692'),(842,2,17,5,'2026-09-23 16:24:35.532146','2026-09-23 16:24:35.532146'),(843,2,18,5,'2026-09-23 16:24:35.543733','2026-09-23 16:24:35.543733'),(844,2,19,5,'2026-09-23 16:24:35.546412','2026-09-23 16:24:35.546412'),(845,2,20,5,'2026-09-23 16:24:35.548854','2026-09-23 16:24:35.548854'),(846,2,21,5,'2026-09-23 16:24:35.551254','2026-09-23 16:24:35.551254'),(847,2,22,5,'2026-09-23 16:24:35.553596','2026-09-23 16:24:35.553596'),(848,2,23,5,'2026-09-23 16:24:35.556093','2026-09-23 16:24:35.556093'),(849,2,24,5,'2026-09-23 16:24:35.558435','2026-09-23 16:24:35.558435'),(850,3,1,5,'2026-09-23 16:24:35.560833','2026-09-23 16:24:35.560833'),(851,3,2,5,'2026-09-23 16:24:35.563401','2026-09-23 16:24:35.563401'),(852,3,3,5,'2026-09-23 16:24:35.565877','2026-09-23 16:24:35.565877'),(853,3,4,5,'2026-09-23 16:24:35.568144','2026-09-23 16:24:35.568144'),(854,3,5,5,'2026-09-23 16:24:35.570447','2026-09-23 16:24:35.570447'),(855,3,6,5,'2026-09-23 16:24:35.572925','2026-09-23 16:24:35.572925'),(856,3,7,5,'2026-09-23 16:24:35.575549','2026-09-23 16:24:35.575549'),(857,3,8,5,'2026-09-23 16:24:35.577988','2026-09-23 16:24:35.577988'),(858,3,9,5,'2026-09-23 16:24:35.580264','2026-09-23 16:24:35.580264'),(859,3,10,5,'2026-09-23 16:24:35.582404','2026-09-23 16:24:35.582404'),(860,3,11,5,'2026-09-23 16:24:35.584653','2026-09-23 16:24:35.584653'),(861,3,12,5,'2026-09-23 16:24:35.586698','2026-09-23 16:24:35.586698'),(862,3,13,5,'2026-09-23 16:24:35.589000','2026-09-23 16:24:35.589000'),(863,3,14,5,'2026-09-23 16:24:35.591083','2026-09-23 16:24:35.591083'),(864,3,15,5,'2026-09-23 16:24:35.593333','2026-09-23 16:24:35.593333'),(865,3,16,5,'2026-09-23 16:24:35.595607','2026-09-23 16:24:35.595607'),(866,3,17,5,'2026-09-23 16:24:35.598497','2026-09-23 16:24:35.598497'),(867,3,18,5,'2026-09-23 16:24:35.600781','2026-09-23 16:24:35.600781'),(868,3,19,5,'2026-09-23 16:24:35.603067','2026-09-23 16:24:35.603067'),(869,3,20,5,'2026-09-23 16:24:35.606183','2026-09-23 16:24:35.606183'),(870,3,21,5,'2026-09-23 16:24:35.609183','2026-09-23 16:24:35.609183'),(871,3,22,5,'2026-09-23 16:24:35.611986','2026-09-23 16:24:35.611986'),(872,3,23,5,'2026-09-23 16:24:35.614529','2026-09-23 16:24:35.614529'),(873,4,1,5,'2026-09-23 16:24:35.617097','2026-09-23 16:24:35.617097'),(874,4,2,5,'2026-09-23 16:24:35.619424','2026-09-23 16:24:35.619424'),(875,4,3,5,'2026-09-23 16:24:35.621774','2026-09-23 16:24:35.621774'),(876,4,4,5,'2026-09-23 16:24:35.624160','2026-09-23 16:24:35.624160'),(877,4,5,5,'2026-09-23 16:24:35.626504','2026-09-23 16:24:35.626504'),(878,4,6,5,'2026-09-23 16:24:35.628911','2026-09-23 16:24:35.628911'),(879,4,7,5,'2026-09-23 16:24:35.631159','2026-09-23 16:24:35.631159'),(880,4,8,5,'2026-09-23 16:24:35.638896','2026-09-23 16:24:35.638896'),(881,4,9,5,'2026-09-23 16:24:35.641711','2026-09-23 16:24:35.641711'),(882,4,10,5,'2026-09-23 16:24:35.653603','2026-09-23 16:24:35.653603'),(883,4,11,5,'2026-09-23 16:24:35.656478','2026-09-23 16:24:35.656478'),(884,4,12,5,'2026-09-23 16:24:35.659314','2026-09-23 16:24:35.659314'),(885,4,13,5,'2026-09-23 16:24:35.661904','2026-09-23 16:24:35.661904'),(886,4,14,5,'2026-09-23 16:24:35.664525','2026-09-23 16:24:35.664525'),(887,4,15,5,'2026-09-23 16:24:35.667111','2026-09-23 16:24:35.667111'),(888,4,16,5,'2026-09-23 16:24:35.675520','2026-09-23 16:24:35.675520'),(889,4,17,5,'2026-09-23 16:24:35.678366','2026-09-23 16:24:35.678366'),(890,4,18,5,'2026-09-23 16:24:35.681384','2026-09-23 16:24:35.681384'),(891,4,19,5,'2026-09-23 16:24:35.693702','2026-09-23 16:24:35.693702'),(892,4,20,5,'2026-09-23 16:24:35.696569','2026-09-23 16:24:35.696569'),(893,4,21,5,'2026-09-23 16:24:35.699004','2026-09-23 16:24:35.699004'),(894,4,22,5,'2026-09-23 16:24:35.701454','2026-09-23 16:24:35.701454'),(895,5,1,5,'2026-09-23 16:24:35.703865','2026-09-23 16:24:35.703865'),(896,5,2,5,'2026-09-23 16:24:35.708631','2026-09-23 16:24:35.708631'),(897,5,3,5,'2026-09-23 16:24:35.712458','2026-09-23 16:24:35.712458'),(898,5,4,5,'2026-09-23 16:24:35.723682','2026-09-23 16:24:35.723682'),(899,5,5,5,'2026-09-23 16:24:35.726387','2026-09-23 16:24:35.726387'),(900,5,6,5,'2026-09-23 16:24:35.728841','2026-09-23 16:24:35.728841'),(901,5,7,5,'2026-09-23 16:24:35.731219','2026-09-23 16:24:35.731219'),(902,5,8,5,'2026-09-23 16:24:35.734911','2026-09-23 16:24:35.734911'),(903,5,9,5,'2026-09-23 16:24:35.743681','2026-09-23 16:24:35.743681'),(904,5,10,5,'2026-09-23 16:24:35.746431','2026-09-23 16:24:35.746431'),(905,5,11,5,'2026-09-23 16:24:35.749088','2026-09-23 16:24:35.749088'),(906,5,12,5,'2026-09-23 16:24:35.751853','2026-09-23 16:24:35.751853'),(907,5,13,5,'2026-09-23 16:24:35.761880','2026-09-23 16:24:35.761880'),(908,5,14,5,'2026-09-23 16:24:35.764626','2026-09-23 16:24:35.764626'),(909,5,15,5,'2026-09-23 16:24:35.767104','2026-09-23 16:24:35.767104'),(910,5,16,5,'2026-09-23 16:24:35.773587','2026-09-23 16:24:35.773587'),(911,5,17,5,'2026-09-23 16:24:35.776112','2026-09-23 16:24:35.776112'),(912,5,18,5,'2026-09-23 16:24:35.782143','2026-09-23 16:24:35.782143'),(913,5,19,5,'2026-09-23 16:24:35.784814','2026-09-23 16:24:35.784814'),(914,5,20,5,'2026-09-23 16:24:35.787174','2026-09-23 16:24:35.787174'),(915,5,21,5,'2026-09-23 16:24:35.793571','2026-09-23 16:24:35.793571'),(916,6,1,5,'2026-09-23 16:24:35.796165','2026-09-23 16:24:35.796165'),(917,6,2,5,'2026-09-23 16:24:35.799545','2026-09-23 16:24:35.799545'),(918,6,3,5,'2026-09-23 16:24:35.803562','2026-09-23 16:24:35.803562'),(919,6,4,5,'2026-09-23 16:24:35.808773','2026-09-23 16:24:35.808773'),(920,6,5,5,'2026-09-23 16:24:35.813549','2026-09-23 16:24:35.813549'),(921,6,6,5,'2026-09-23 16:24:35.816136','2026-09-23 16:24:35.816136'),(922,6,7,5,'2026-09-23 16:24:35.825374','2026-09-23 16:24:35.825374'),(923,6,8,5,'2026-09-23 16:24:35.827949','2026-09-23 16:24:35.827949'),(924,6,9,5,'2026-09-23 16:24:35.830317','2026-09-23 16:24:35.830317'),(925,6,10,5,'2026-09-23 16:24:35.832768','2026-09-23 16:24:35.832768'),(926,6,11,5,'2026-09-23 16:24:35.843662','2026-09-23 16:24:35.843662'),(927,6,12,5,'2026-09-23 16:24:35.846245','2026-09-23 16:24:35.846245'),(928,6,13,5,'2026-09-23 16:24:35.848729','2026-09-23 16:24:35.848729'),(929,6,14,5,'2026-09-23 16:24:35.850999','2026-09-23 16:24:35.850999'),(930,6,15,5,'2026-09-23 16:24:35.853267','2026-09-23 16:24:35.853267'),(931,6,16,5,'2026-09-23 16:24:35.861283','2026-09-23 16:24:35.861283'),(932,6,17,5,'2026-09-23 16:24:35.863954','2026-09-23 16:24:35.863954'),(933,6,18,5,'2026-09-23 16:24:35.866480','2026-09-23 16:24:35.866480'),(934,6,19,5,'2026-09-23 16:24:35.870076','2026-09-23 16:24:35.870076'),(935,7,1,5,'2026-09-23 16:24:35.873539','2026-09-23 16:24:35.873539'),(936,7,2,5,'2026-09-23 16:24:35.883653','2026-09-23 16:24:35.883653'),(937,7,3,5,'2026-09-23 16:24:35.886298','2026-09-23 16:24:35.886298'),(938,7,4,5,'2026-09-23 16:24:35.888904','2026-09-23 16:24:35.888904'),(939,7,5,5,'2026-09-23 16:24:35.891328','2026-09-23 16:24:35.891328'),(940,7,6,5,'2026-09-23 16:24:35.903645','2026-09-23 16:24:35.903645'),(941,7,7,5,'2026-09-23 16:24:35.906376','2026-09-23 16:24:35.906376'),(942,7,8,5,'2026-09-23 16:24:35.908879','2026-09-23 16:24:35.908879'),(943,7,9,5,'2026-09-23 16:24:35.911291','2026-09-23 16:24:35.911291'),(944,7,10,5,'2026-09-23 16:24:35.913630','2026-09-23 16:24:35.913630'),(945,7,11,5,'2026-09-23 16:24:35.915994','2026-09-23 16:24:35.915994'),(946,7,12,5,'2026-09-23 16:24:35.918646','2026-09-23 16:24:35.918646'),(947,7,13,5,'2026-09-23 16:24:35.927475','2026-09-23 16:24:35.927475'),(948,7,14,5,'2026-09-23 16:24:35.935650','2026-09-23 16:24:35.935650'),(949,7,15,5,'2026-09-23 16:24:35.939300','2026-09-23 16:24:35.939300'),(950,7,16,5,'2026-09-23 16:24:35.945172','2026-09-23 16:24:35.945172'),(951,7,17,5,'2026-09-23 16:24:35.950601','2026-09-23 16:24:35.950601'),(952,7,18,5,'2026-09-23 16:24:35.964850','2026-09-23 16:24:35.964850'),(953,8,1,5,'2026-09-23 16:24:35.973686','2026-09-23 16:24:35.973686'),(954,8,2,5,'2026-09-23 16:24:35.976363','2026-09-23 16:24:35.976363'),(955,8,3,5,'2026-09-23 16:24:35.978907','2026-09-23 16:24:35.978907'),(956,8,4,5,'2026-09-23 16:24:36.032342','2026-09-23 16:24:36.032342'),(957,8,5,5,'2026-09-23 16:24:36.043845','2026-09-23 16:24:36.043845'),(958,8,6,5,'2026-09-23 16:24:36.053664','2026-09-23 16:24:36.053664'),(959,8,7,5,'2026-09-23 16:24:36.056386','2026-09-23 16:24:36.056386'),(960,8,8,5,'2026-09-23 16:24:36.058890','2026-09-23 16:24:36.058890'),(961,8,9,5,'2026-09-23 16:24:36.067576','2026-09-23 16:24:36.067576'),(962,8,10,5,'2026-09-23 16:24:36.072884','2026-09-23 16:24:36.072884'),(963,8,11,5,'2026-09-23 16:24:36.082818','2026-09-23 16:24:36.082818'),(964,8,12,5,'2026-09-23 16:24:36.093598','2026-09-23 16:24:36.093598'),(965,8,13,5,'2026-09-23 16:24:36.101630','2026-09-23 16:24:36.101630'),(966,8,14,5,'2026-09-23 16:24:36.104279','2026-09-23 16:24:36.104279'),(967,8,15,5,'2026-09-23 16:24:36.106852','2026-09-23 16:24:36.106852'),(968,8,16,5,'2026-09-23 16:24:36.109338','2026-09-23 16:24:36.109338'),(969,8,17,5,'2026-09-23 16:24:36.117788','2026-09-23 16:24:36.117788'),(970,9,1,5,'2026-09-23 16:24:36.120713','2026-09-23 16:24:36.120713'),(971,9,2,5,'2026-09-23 16:24:36.133659','2026-09-23 16:24:36.133659'),(972,9,3,5,'2026-09-23 16:24:36.136408','2026-09-23 16:24:36.136408'),(973,9,4,5,'2026-09-23 16:24:36.143645','2026-09-23 16:24:36.143645'),(974,9,5,5,'2026-09-23 16:24:36.153738','2026-09-23 16:24:36.153738'),(975,9,6,5,'2026-09-23 16:24:36.161835','2026-09-23 16:24:36.161835'),(976,9,7,5,'2026-09-23 16:24:36.164639','2026-09-23 16:24:36.164639'),(977,9,8,5,'2026-09-23 16:24:36.173218','2026-09-23 16:24:36.173218'),(978,9,9,5,'2026-09-23 16:24:36.177949','2026-09-23 16:24:36.177949'),(979,9,10,5,'2026-09-23 16:24:36.183594','2026-09-23 16:24:36.183594'),(980,9,11,5,'2026-09-23 16:24:36.193592','2026-09-23 16:24:36.193592'),(981,9,12,5,'2026-09-23 16:24:36.198868','2026-09-23 16:24:36.198868'),(982,9,13,5,'2026-09-23 16:24:36.202328','2026-09-23 16:24:36.202328'),(983,9,14,5,'2026-09-23 16:24:36.205041','2026-09-23 16:24:36.205041'),(984,9,15,5,'2026-09-23 16:24:36.213667','2026-09-23 16:24:36.213667'),(985,9,16,5,'2026-09-23 16:24:36.218081','2026-09-23 16:24:36.218081'),(986,10,1,5,'2026-09-23 16:24:36.226260','2026-09-23 16:24:36.226260'),(987,10,2,5,'2026-09-23 16:24:36.233604','2026-09-23 16:24:36.233604'),(988,10,3,5,'2026-09-23 16:24:36.243725','2026-09-23 16:24:36.243725'),(989,10,4,5,'2026-09-23 16:24:36.253656','2026-09-23 16:24:36.253656'),(990,10,5,5,'2026-09-23 16:24:36.261168','2026-09-23 16:24:36.261168'),(991,10,6,5,'2026-09-23 16:24:36.263854','2026-09-23 16:24:36.263854'),(992,10,7,5,'2026-09-23 16:24:36.268501','2026-09-23 16:24:36.268501'),(993,10,8,5,'2026-09-23 16:24:36.273485','2026-09-23 16:24:36.273485'),(994,10,9,5,'2026-09-23 16:24:36.279352','2026-09-23 16:24:36.279352'),(995,10,10,5,'2026-09-23 16:24:36.293722','2026-09-23 16:24:36.293722'),(996,10,11,5,'2026-09-23 16:24:36.318017','2026-09-23 16:24:36.318017'),(997,10,12,5,'2026-09-23 16:24:36.340887','2026-09-23 16:24:36.340887'),(998,10,13,5,'2026-09-23 16:24:36.353710','2026-09-23 16:24:36.353710'),(999,10,14,5,'2026-09-23 16:24:36.361889','2026-09-23 16:24:36.361889'),(1000,10,15,5,'2026-09-23 16:24:36.364643','2026-09-23 16:24:36.364643');
/*!40000 ALTER TABLE `seat` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `seat_hold`
--

DROP TABLE IF EXISTS `seat_hold`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `seat_hold` (
  `seat_hold_id` bigint NOT NULL AUTO_INCREMENT,
  `concert_id` bigint NOT NULL,
  `seat_id` bigint NOT NULL,
  `member_id` bigint NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `released_at` datetime(6) DEFAULT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `active_seat` bigint GENERATED ALWAYS AS (if((`status` = _utf8mb4'HELD'),`seat_id`,NULL)) STORED,
  `active_member` bigint GENERATED ALWAYS AS (if((`status` = _utf8mb4'HELD'),`member_id`,NULL)) STORED,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`seat_hold_id`),
  UNIQUE KEY `uk_hold_seat` (`concert_id`,`active_seat`),
  UNIQUE KEY `uk_hold_member` (`concert_id`,`active_member`),
  KEY `ix_hold_expire` (`status`,`expires_at`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `seat_hold`
--

LOCK TABLES `seat_hold` WRITE;
/*!40000 ALTER TABLE `seat_hold` DISABLE KEYS */;
INSERT INTO `seat_hold` VALUES (1,48,35,2,'2026-09-23 16:34:57.587948','2026-09-23 16:29:59.191981','CONVERTED',NULL,NULL,'2026-09-23 16:29:57.688480','2026-09-23 16:29:59.229839'),(2,48,142,4,'2026-09-24 00:36:06.711741','2026-09-24 00:31:07.960146','CONVERTED',NULL,NULL,'2026-09-24 00:31:06.735888','2026-09-24 00:31:07.990088'),(3,48,907,4,'2026-09-24 00:36:26.200182','2026-09-24 00:31:27.317919','CONVERTED',NULL,NULL,'2026-09-24 00:31:26.218177','2026-09-24 00:31:27.338998'),(4,79,17,3,'2026-09-24 22:36:03.422729','2026-09-24 22:32:41.734022','RELEASED',NULL,NULL,'2026-09-24 22:31:03.545288','2026-09-24 22:32:41.748260'),(5,79,1,3,'2026-09-24 22:53:20.857059','2026-09-24 22:50:50.131593','RELEASED',NULL,NULL,'2026-09-24 22:48:20.875602','2026-09-24 22:50:50.142630'),(6,78,18,3,'2026-09-24 22:58:36.277940','2026-09-24 22:53:38.363922','RELEASED',NULL,NULL,'2026-09-24 22:53:36.292233','2026-09-24 22:53:38.371186'),(7,12,17,3,'2026-09-24 23:00:50.631648','2026-09-24 22:55:51.918328','CONVERTED',NULL,NULL,'2026-09-24 22:55:50.645105','2026-09-24 22:55:51.962360');
/*!40000 ALTER TABLE `seat_hold` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `section`
--

DROP TABLE IF EXISTS `section`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `section` (
  `section_id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `grade` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `price` int NOT NULL,
  `seat_count` int NOT NULL,
  `row_count` int DEFAULT NULL,
  `seat_per_row` int DEFAULT NULL,
  `venue_id` bigint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`section_id`),
  UNIQUE KEY `uk_section_venue_name` (`venue_id`,`name`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `section`
--

LOCK TABLES `section` WRITE;
/*!40000 ALTER TABLE `section` DISABLE KEYS */;
INSERT INTO `section` VALUES (1,'A구역','COMMON',150000,200,10,25,1,'2026-09-23 16:24:31.902370','2026-09-23 16:24:36.404747'),(2,'B구역','COMMON',150000,200,10,25,1,'2026-09-23 16:24:33.038049','2026-09-23 16:24:36.411157'),(3,'C구역','COMMON',120000,200,10,22,1,'2026-09-23 16:24:33.928279','2026-09-23 16:24:36.427099'),(4,'2층 D구역','COMMON',120000,200,10,25,1,'2026-09-23 16:24:34.540220','2026-09-23 16:24:36.443979'),(5,'2층 E구역','COMMON',99000,200,10,25,1,'2026-09-23 16:24:35.344213','2026-09-23 16:24:36.446149');
/*!40000 ALTER TABLE `section` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ticket`
--

DROP TABLE IF EXISTS `ticket`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ticket` (
  `ticket_id` bigint NOT NULL AUTO_INCREMENT,
  `reservation_id` bigint NOT NULL,
  `owner_member_id` bigint NOT NULL,
  `acquired_by` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `acquired_at` datetime(6) NOT NULL,
  `token_id` decimal(38,0) DEFAULT NULL,
  `mint_tx_hash` varchar(66) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mint_attempt_count` int NOT NULL,
  `failure_reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`ticket_id`),
  UNIQUE KEY `uk_ticket_reservation` (`reservation_id`),
  UNIQUE KEY `uk_ticket_token_id` (`token_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ticket`
--

LOCK TABLES `ticket` WRITE;
/*!40000 ALTER TABLE `ticket` DISABLE KEYS */;
INSERT INTO `ticket` VALUES (1,1,2,'BOOKING','2026-09-23 16:24:42.901128',1,'0x87b82a5617d36d9ce1f76a45f5bf4daf5079f643224f8c4282eada981cac26aa',1,NULL,'USED','2026-09-23 16:24:42.912409','2026-09-23 16:24:42.912409'),(2,2,2,'BOOKING','2026-09-23 16:29:59.210362',2,'0x2856d34fd410e850e7b405ca0207e2443f659062512326e1b95c36a73e24aace',1,NULL,'OWNED','2026-09-23 16:29:59.213525','2026-09-23 16:29:59.358719'),(3,3,4,'BOOKING','2026-09-24 00:31:07.971155',NULL,NULL,1,'트랜잭션 전송 실패(chargeForBooking): Error: VM Exception while processing transaction: reverted with custom error \'ERC20InsufficientBalance(\"0x480D53B23D3fB25458b4ccd5b733022af851cB14\", 0, 150000)\'','MINT_FAILED','2026-09-24 00:31:07.977681','2026-09-24 00:31:09.133722'),(4,4,4,'BOOKING','2026-09-24 00:31:27.328255',3,'0xbd5416779d17b1fefbfb587be7bd466101ff6372cfbadc65966153be7461c7c7',1,NULL,'LISTED','2026-09-24 00:31:27.331809','2026-09-24 00:31:42.298082'),(5,5,3,'BOOKING','2026-09-24 22:55:51.925481',4,'0xe3551a59be8881a73beb613866110aa671479b54e7e2320100c0c329185e502b',1,NULL,'OWNED','2026-09-24 22:55:51.936988','2026-09-24 22:55:52.092219');
/*!40000 ALTER TABLE `ticket` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ticket_listing`
--

DROP TABLE IF EXISTS `ticket_listing`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ticket_listing` (
  `listing_id` bigint NOT NULL AUTO_INCREMENT,
  `ticket_id` bigint NOT NULL,
  `seller_member_id` bigint NOT NULL,
  `concert_id` bigint NOT NULL,
  `section_id` bigint NOT NULL,
  `seat_no` int NOT NULL,
  `seat_col` int NOT NULL,
  `price` bigint NOT NULL,
  `face_value` bigint NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `listed_at` datetime(6) NOT NULL,
  `closed_at` datetime(6) DEFAULT NULL,
  `active_ticket` bigint GENERATED ALWAYS AS (if((`status` = _utf8mb4'LISTED'),`ticket_id`,NULL)) STORED,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`listing_id`),
  UNIQUE KEY `uk_listing_ticket_active` (`active_ticket`),
  KEY `idx_listing_concert_status_price` (`concert_id`,`status`,`price`),
  KEY `idx_listing_seller_status` (`seller_member_id`,`status`),
  KEY `idx_listing_ticket` (`ticket_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ticket_listing`
--

LOCK TABLES `ticket_listing` WRITE;
/*!40000 ALTER TABLE `ticket_listing` DISABLE KEYS */;
INSERT INTO `ticket_listing` VALUES (1,4,4,48,5,5,13,68300,99000,'LISTED','2026-09-24 00:31:42.266973',NULL,4,'2026-09-24 00:31:42.270046','2026-09-24 00:31:42.270046');
/*!40000 ALTER TABLE `ticket_listing` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ticket_trade`
--

DROP TABLE IF EXISTS `ticket_trade`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ticket_trade` (
  `trade_id` bigint NOT NULL AUTO_INCREMENT,
  `listing_id` bigint NOT NULL,
  `ticket_id` bigint NOT NULL,
  `seller_member_id` bigint NOT NULL,
  `buyer_member_id` bigint NOT NULL,
  `price` bigint NOT NULL,
  `traded_at` datetime(6) NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`trade_id`),
  UNIQUE KEY `uk_ticket_trade_listing` (`listing_id`),
  KEY `idx_trade_buyer` (`buyer_member_id`,`traded_at`),
  KEY `idx_trade_ticket` (`ticket_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ticket_trade`
--

LOCK TABLES `ticket_trade` WRITE;
/*!40000 ALTER TABLE `ticket_trade` DISABLE KEYS */;
/*!40000 ALTER TABLE `ticket_trade` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `venue`
--

DROP TABLE IF EXISTS `venue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `venue` (
  `venue_id` bigint NOT NULL AUTO_INCREMENT,
  `venue_name` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `venue_address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `total_seat_count` int NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`venue_id`),
  UNIQUE KEY `uk_venue_name` (`venue_name`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `venue`
--

LOCK TABLES `venue` WRITE;
/*!40000 ALTER TABLE `venue` DISABLE KEYS */;
INSERT INTO `venue` VALUES (1,'고척돔','서울시 구로구 경인로 430',1000,'2026-09-23 07:24:13.610777','2026-09-23 07:24:13.610777');
/*!40000 ALTER TABLE `venue` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wallet`
--

DROP TABLE IF EXISTS `wallet`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `wallet` (
  `member_id` bigint NOT NULL,
  `address` varchar(42) COLLATE utf8mb4_unicode_ci NOT NULL,
  `encrypted_keystore_json` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `wrapped_dek` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`member_id`),
  UNIQUE KEY `uk_wallet_address` (`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wallet`
--

LOCK TABLES `wallet` WRITE;
/*!40000 ALTER TABLE `wallet` DISABLE KEYS */;
INSERT INTO `wallet` VALUES (1,'0x26a44375790f5760144e2146403e728774ca9895','{\"address\":\"26a44375790f5760144e2146403e728774ca9895\",\"id\":\"2de62fee-71b5-4246-8aec-79518bde7cba\",\"version\":3,\"crypto\":{\"cipher\":\"aes-128-ctr\",\"ciphertext\":\"a17703c72f4e3ae3456d0a2bf95e5ac42847c35b453653a833c52b67bfe63c83\",\"cipherparams\":{\"iv\":\"be9fa3b343538c02959e66dfd4e60bf3\"},\"kdf\":\"scrypt\",\"kdfparams\":{\"dklen\":32,\"n\":262144,\"p\":1,\"r\":8,\"salt\":\"bc62931e792768996cb258f23fda52eb849755e81cbd094601641a84bcd6cc17\"},\"mac\":\"3c919252ce698cad097b435343dfa7584bf53ffdae9ef3780e957abb87486e56\"}}','9d4+Pfe+34EXBUmvXqmJxwWY/Iy4hTPXEF1utX5SF+F3R1zvjQn6wqnHUCKyS8fJgrk6uvlXKfDttFzS','2026-09-23 16:24:38.772028','2026-09-23 16:24:38.772028'),(2,'0x5c753a03a5687904e6483931f56188e6268f2192','{\"address\":\"5c753a03a5687904e6483931f56188e6268f2192\",\"id\":\"db42aa31-725b-40a8-b551-ec2c6be21fee\",\"version\":3,\"crypto\":{\"cipher\":\"aes-128-ctr\",\"ciphertext\":\"4a8179c4f30ac5a3ce7d0aa7781227e033bb19ffdd8f762c188268416ed7c1b3\",\"cipherparams\":{\"iv\":\"9d64062f60f1bd3d8979eeaa6feeca3f\"},\"kdf\":\"scrypt\",\"kdfparams\":{\"dklen\":32,\"n\":262144,\"p\":1,\"r\":8,\"salt\":\"453d5e2e0565d4c0ef7f15df3f8ff02317f046c763a73e2898702034e471c382\"},\"mac\":\"b9c8795b0526d1fb751d13d5586ee49938acb280ae0c60a5c6859851748218ca\"}}','YILmbm9yLiRuYp8HUPhCShk58j+VXhQYB3IPJVczUsVnnYgZWlvqhllRylAqRfb5p7H/uc0nG2HSpC+e','2026-09-23 16:24:42.720513','2026-09-23 16:24:42.720513'),(3,'0x52187c8859e3215c928f3504c6864b7d7551a80c','{\"address\":\"52187c8859e3215c928f3504c6864b7d7551a80c\",\"id\":\"97d6a3b2-5268-4401-94dd-777bb6c133cc\",\"version\":3,\"crypto\":{\"cipher\":\"aes-128-ctr\",\"ciphertext\":\"ceefb9637b0eaed5ec3bba89cd613778ac1c05b5b7923c91fc9c40d9f6b6efbf\",\"cipherparams\":{\"iv\":\"f41fda31dcbf671efae0eadc4b890be1\"},\"kdf\":\"scrypt\",\"kdfparams\":{\"dklen\":32,\"n\":262144,\"p\":1,\"r\":8,\"salt\":\"afc35159a7da7773b515838b7386737892de8130bf88027d56314d029cc88071\"},\"mac\":\"935a763d5d4d3d67396ff7d4fc3314bf1463015268670e4adcc342190cef4514\"}}','+i1IaZvog6uDKJPT/pC+zL8RheDnfb0o0X/i+Qpz69w5f3TGwpi9oqur/d+EhUjcP8jbBk4saUaPVND8','2026-09-23 21:45:24.603331','2026-09-23 21:45:24.603331'),(4,'0x480d53b23d3fb25458b4ccd5b733022af851cb14','{\"address\":\"480d53b23d3fb25458b4ccd5b733022af851cb14\",\"id\":\"b4034737-886a-481e-8d9e-7febf67abf54\",\"version\":3,\"crypto\":{\"cipher\":\"aes-128-ctr\",\"ciphertext\":\"41e023b11e9b075b10b5c74656d1627a4d1ef9c03d8e9e812c4aedb9908fda07\",\"cipherparams\":{\"iv\":\"9adf585fb94e1bd874c3faf664404436\"},\"kdf\":\"scrypt\",\"kdfparams\":{\"dklen\":32,\"n\":262144,\"p\":1,\"r\":8,\"salt\":\"242f5a9d221b58bdb6478ab86cc59eaf65edd6ce2bc6b0ecb176a57782241b76\"},\"mac\":\"551cdf12032aed7bfc5fdee0e2a06b7a5fd16948c40c09e9e19a987789d05237\"}}','rUp9wu5GULKCDh5ZILgLYxh8qIWRaqFTR9oNVgtJvKxcjryhLi9sytBb2RUr/aVBKMYd7R5h1WodVKku','2026-09-24 00:30:43.353663','2026-09-24 00:30:43.353663'),(5,'0x15a319a2f8b62c09a918b8ba68b8a9539ca33d01','{\"address\":\"15a319a2f8b62c09a918b8ba68b8a9539ca33d01\",\"id\":\"8161df61-4e83-4416-b5bd-8e7d970b4d5d\",\"version\":3,\"crypto\":{\"cipher\":\"aes-128-ctr\",\"ciphertext\":\"a732b1c7b30a7d071f24f623aaf0be489d8f91486871970a4081579d82f9d32d\",\"cipherparams\":{\"iv\":\"77d41e01a2d730068ae79af02936c275\"},\"kdf\":\"scrypt\",\"kdfparams\":{\"dklen\":32,\"n\":262144,\"p\":1,\"r\":8,\"salt\":\"2c5d69bb54396c9bddeea0bf47a6141ba95792c5b405d1dd7e7e51676f6b42d6\"},\"mac\":\"ae70e553d004695ac77d43ec8a54ed2296a24ca2d60e637bc66f9e939314ca00\"}}','AAo+HdBKNBdKrqi5gr9Gh+GDecdwM7ifv3HVLtG7qSUfkIzoQBUQ5HvGPzosRsby0NYiLtF4ktiMQquk','2026-09-24 20:27:55.522319','2026-09-24 20:27:55.522319');
/*!40000 ALTER TABLE `wallet` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wallet_transaction`
--

DROP TABLE IF EXISTS `wallet_transaction`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `wallet_transaction` (
  `wallet_transaction_id` bigint NOT NULL AUTO_INCREMENT,
  `member_id` bigint NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` decimal(38,0) NOT NULL,
  `balance_after` decimal(38,0) NOT NULL,
  `source` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`wallet_transaction_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wallet_transaction`
--

LOCK TABLES `wallet_transaction` WRITE;
/*!40000 ALTER TABLE `wallet_transaction` DISABLE KEYS */;
INSERT INTO `wallet_transaction` VALUES (1,2,'머쉬룸 충전',150000,150000,'PG 모의 결제','2026-09-23 16:29:35.245279','2026-09-23 16:29:35.245279'),(2,2,'머쉬룸 충전',1000000,1000000,'PG 모의 결제','2026-09-23 16:39:16.152578','2026-09-23 16:39:16.152578'),(3,4,'머쉬룸 충전',150000,150000,'PG 모의 결제','2026-09-24 00:31:18.201166','2026-09-24 00:31:18.201166'),(4,3,'머쉬룸 충전',150000,150000,'PG 모의 결제','2026-09-24 22:48:00.864016','2026-09-24 22:48:00.864016');
/*!40000 ALTER TABLE `wallet_transaction` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'ticketing'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-09-25 13:02:53
