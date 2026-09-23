-- Existing tables only: 48 concerts / 64 artists / 66 artist links / 74 detail images.
-- No CREATE, DROP, ALTER, DELETE, TRUNCATE or procedures.
-- Requires venue_id=1. Existing artist profiles are preserved.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- artist ----------------------------------------------------------
-- artist_name 에는 unique 가 없다. 기존 시드의 김필·이승기·로이킴이 크롤링 결과에도
-- 있어서, 직접 걸러 내지 않으면 같은 이름이 두 벌 생긴다.
INSERT INTO artist (artist_name, profile_image, created_at, updated_at)
SELECT m.artist_name, m.profile_image, NOW(6), NOW(6)
FROM (
    SELECT 'KEY' AS artist_name, 'artist/artist_key.png' AS profile_image
    UNION ALL SELECT 'TAKUYA KIMURA', 'artist/artist_takuya_kimura.jpg'
    UNION ALL SELECT '김장훈', 'artist/artist_gimjanghun.jpg'
    UNION ALL SELECT '김광진', 'artist/artist_gimgwangjin.gif'
    UNION ALL SELECT '볼빨간사춘기', 'artist/artist_bolppalgansachungi.gif'
    UNION ALL SELECT '산다라박', 'artist/artist_sandarabak.gif'
    UNION ALL SELECT '선우정아', 'artist/artist_seonujeonga.gif'
    UNION ALL SELECT '소수빈', 'artist/artist_sosubin.gif'
    UNION ALL SELECT '홍이삭', 'artist/artist_hongisak.gif'
    UNION ALL SELECT '송소희', 'artist/artist_songsohui.gif'
    UNION ALL SELECT '추다혜', 'artist/artist_chudahye.gif'
    UNION ALL SELECT '앙상블 시나위', 'artist/artist_angsangbeul_sinawi.gif'
    UNION ALL SELECT 'LEO MUSE', 'artist/artist_leo_muse.png'
    UNION ALL SELECT '홍경민', 'artist/artist_honggyeongmin.jpg'
    UNION ALL SELECT '산들', 'artist/artist_sandeul.jpg'
    UNION ALL SELECT '＆TEAM', NULL
    UNION ALL SELECT '레이니', 'artist/artist_reini.jpg'
    UNION ALL SELECT '조관우', 'artist/artist_jogwanu.jpg'
    UNION ALL SELECT 'PENTAGON', NULL
    UNION ALL SELECT '찰리 푸스', 'artist/artist_chalri_puseu.jpg'
    UNION ALL SELECT '장윤정', 'artist/artist_jangyunjeong.jpg'
    UNION ALL SELECT '김동률', NULL
    UNION ALL SELECT 'ILLIT', 'artist/artist_illit.png'
    UNION ALL SELECT 'NEXZ', NULL
    UNION ALL SELECT 'ano', NULL
    UNION ALL SELECT '이승기', 'artist/artist_iseunggi.png'
    UNION ALL SELECT '조슈아 레드먼 쿼텟', NULL
    UNION ALL SELECT '다이나믹 듀오', 'artist/artist_dainamik_dyuo.gif'
    UNION ALL SELECT 'Minos (마이노스)', 'artist/artist_minos_mainoseu.gif'
    UNION ALL SELECT '허클베리피', 'artist/artist_heokeulberipi.gif'
    UNION ALL SELECT '범키', 'artist/artist_beomki.gif'
    UNION ALL SELECT '한해', 'artist/artist_hanhae.gif'
    UNION ALL SELECT '치타', 'artist/artist_chita.gif'
    UNION ALL SELECT '그리', 'artist/artist_geuri.gif'
    UNION ALL SELECT '슬리피', 'artist/artist_seulripi.gif'
    UNION ALL SELECT '김수희', 'artist/artist_gimsuhui.jpg'
    UNION ALL SELECT '심규선', 'artist/artist_simgyuseon.png'
    UNION ALL SELECT '벤슨 분', NULL
    UNION ALL SELECT '키퍼', 'artist/artist_kipeo.jpg'
    UNION ALL SELECT '김재환', 'artist/artist_gimjaehwan.jpg'
    UNION ALL SELECT 'Nujabes Metaphorical Ensemble', NULL
    UNION ALL SELECT '이창민', 'artist/artist_ichangmin.jpg'
    UNION ALL SELECT '코이키즈(KO1KEYZ)', NULL
    UNION ALL SELECT '남진', NULL
    UNION ALL SELECT '까치산', NULL
    UNION ALL SELECT '이은미', NULL
    UNION ALL SELECT 'Morgenshtern Alisher', 'artist/artist_morgenshtern_alisher.jpg'
    UNION ALL SELECT '윤종신', 'artist/artist_yunjongsin.jpg'
    UNION ALL SELECT '김필', NULL
    UNION ALL SELECT '최유리', 'artist/artist_choeyuri.jpg'
    UNION ALL SELECT '제시 골드', NULL
    UNION ALL SELECT '로이킴', 'artist/artist_roikim.jpg'
    UNION ALL SELECT 'LET ME KNOW', NULL
    UNION ALL SELECT 'Sunny Day Service', NULL
    UNION ALL SELECT 'YUURI', NULL
    UNION ALL SELECT '카키', NULL
    UNION ALL SELECT '칼리드', 'artist/artist_kalrideu.jpg'
    UNION ALL SELECT 'FKJ', NULL
    UNION ALL SELECT 'KWON JIN AH', 'artist/artist_kwon_jin_ah.png'
    UNION ALL SELECT '마오 스즈키', 'artist/artist_mao_seujeuki.gif'
    UNION ALL SELECT '카즈미 타테이시', 'artist/artist_kajeumi_tateisi.gif'
    UNION ALL SELECT '시노부 사토', 'artist/artist_sinobu_sato.gif'
    UNION ALL SELECT '마룬5', 'artist/artist_marun5.jpg'
    UNION ALL SELECT '브루노 마스', 'artist/artist_beuruno_maseu.jpg'
) m
LEFT JOIN artist a ON a.artist_name = m.artist_name
WHERE a.artist_id IS NULL;

-- concert ---------------------------------------------------------
-- 공연장은 전부 venue_id = 1 하나를 가리킨다. NOL 의 실제 공연장 이름은
-- concerts.json / concerts.csv 에 남아 있다.
INSERT INTO concert (title, genre, poster_image_key, description, age_rating, status,
                    view_count, start_date, end_date, open_at, venue_id,
                    created_at, updated_at)
SELECT m.title, m.genre, m.poster_image_key, m.description, m.age_rating, m.status,
       0, m.start_date, m.end_date, m.open_at,
       1,
       NOW(6), NOW(6)
FROM (
    SELECT '2026 KEY B-day PARTY ［KEYdult Club］' AS title, 'CONCERT' AS genre, 'poster/poster_main_key_b_day_party_keydult_club.gif' AS poster_image_key, '2026 KEY B-day PARTY ［KEYdult Club］' AS description, 'AGE_7' AS age_rating, 'ON_SALE' AS status, '2026-09-23 16:00:00' AS start_date, '2026-09-23 18:00:00' AS end_date, '2026-09-09 19:00:00' AS open_at
    UNION ALL SELECT 'TAKUYA KIMURA Live Tour 2026 Checkpoint in Seoul', 'CONCERT', 'poster/poster_main_takuya_kimura_2026_checkpoint_seoul.gif', 'TAKUYA KIMURA Live Tour 2026 Checkpoint in Seoul', 'AGE_7', 'ON_SALE', '2026-09-26 16:00:00', '2026-09-26 18:00:00', '2026-06-29 19:00:00'
    UNION ALL SELECT '2026 김장훈 전국투어 콘서트 : 원맨쇼 - 제주', 'CONCERT', 'poster/poster_main_gimjanghun_wonmaensyo_jeju.gif', '2026 김장훈 전국투어 콘서트 : 원맨쇼 - 제주', 'AGE_7', 'ON_SALE', '2026-09-27 18:00:00', '2026-09-27 20:00:00', '2026-06-19 09:00:00'
    UNION ALL SELECT '충주 파크뮤직페스티벌 WITH GUGAK', 'CONCERT', 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '충주 파크뮤직페스티벌 WITH GUGAK', 'AGE_7', 'ON_SALE', '2026-10-03 13:30:00', '2026-10-03 21:30:00', '2026-08-28 14:00:00'
    UNION ALL SELECT '2026 LEO MUSE FANMEETING ［TAKE 운－PLAY LEO］', 'CONCERT', 'poster/poster_main_leo_muse_fanmeeting_take_un_play_leo.gif', '2026 LEO MUSE FANMEETING ［TAKE 운－PLAY LEO］', 'AGE_7', 'ON_SALE', '2026-10-03 14:00:00', '2026-10-03 15:40:00', '2026-09-07 19:00:00'
    UNION ALL SELECT '홍경민 콘서트-10월의 매달리스트 콘서트', 'CONCERT', 'poster/poster_main_honggyeongmin_10wolui_maedalriseuteu.gif', '그 때의 나로 돌아갑니다.', 'AGE_7', 'ON_SALE', '2026-10-03 15:00:00', '2026-10-03 17:30:00', '2026-09-07 12:00:00'
    UNION ALL SELECT '2026 산들 단독 콘서트 〈바람결〉', 'CONCERT', 'poster/poster_main_sandeul_baramgyeol.gif', '2026 산들 단독 콘서트 〈바람결〉', 'AGE_7', 'ON_SALE', '2026-10-03 18:00:00', '2026-10-03 20:00:00', '2026-09-08 20:00:00'
    UNION ALL SELECT '2026 ＆TEAM CONCERT TOUR ‘BLAZE THE WAY’ ENCORE in KSPO DOME', 'CONCERT', 'poster/poster_main_team_blaze_way_encore_kspo_dome.gif', '2026 ＆TEAM CONCERT TOUR ‘BLAZE THE WAY’ ENCORE in KSPO DOME', 'AGE_7', 'ON_SALE', '2026-10-03 18:00:00', '2026-10-03 20:00:00', '2026-08-11 20:00:00'
    UNION ALL SELECT '레이니 내한공연', 'CONCERT', 'poster/poster_main_reini.gif', 'LANY: soft world tour in Korea', 'AGE_12', 'ON_SALE', '2026-10-03 19:00:00', '2026-10-03 21:00:00', '2026-03-31 12:00:00'
    UNION ALL SELECT '2026 조관우 MUSIC 콘서트 - 가을의 기적(부천)', 'CONCERT', 'poster/poster_main_jogwanu_music_gaeului_gijeok_bucheon.gif', '2026 조관우 MUSIC 콘서트 - 가을의 기적(부천)', 'AGE_7', 'ON_SALE', '2026-10-04 17:00:00', '2026-10-04 19:30:00', '2026-08-27 14:00:00'
    UNION ALL SELECT 'PENTAGON 10th Anniversary Tour 〈101010〉 in Seoul', 'CONCERT', 'poster/poster_main_pentagon_10th_anniversary_101010_seoul.gif', 'PENTAGON 10th Anniversary Tour 〈101010〉 in Seoul', 'AGE_7', 'ON_SALE', '2026-10-09 19:00:00', '2026-10-09 20:40:00', '2026-09-08 20:00:00'
    UNION ALL SELECT '찰리 푸스 내한공연', 'CONCERT', 'poster/poster_main_chalri_puseu.gif', 'Charlie Puth - Whatever’s Clever! World Tour in Seoul', 'AGE_12', 'ON_SALE', '2026-10-11 19:00:00', '2026-10-11 21:00:00', '2026-04-29 12:00:00'
    UNION ALL SELECT '［부산］ 2026 장윤정 라이브 콘서트 〈THE MASTER〉', 'CONCERT', 'poster/poster_main_busan_2026_jangyunjeong_master.gif', '［부산］ 2026 장윤정 라이브 콘서트 〈THE MASTER〉', 'AGE_7', 'ON_SALE', '2026-10-17 14:00:00', '2026-10-17 16:00:00', '2026-08-06 15:00:00'
    UNION ALL SELECT '2026 김동률 콘서트 ‘오래된 노래’', 'CONCERT', 'poster/poster_main_gimdongryul_oraedoen_norae.gif', '2026 김동률 콘서트 ‘오래된 노래’', 'AGE_7', 'ON_SALE', '2026-10-17 17:00:00', '2026-10-17 19:30:00', '2026-09-04 17:00:00'
    UNION ALL SELECT 'ILLIT LIVE ‘PRESS START♥’ ENCORE in KOREA', 'CONCERT', 'poster/poster_main_illit_press_start_encore_korea.gif', 'ILLIT LIVE ‘PRESS START♥’ ENCORE in KOREA', 'AGE_7', 'ON_SALE', '2026-10-17 18:00:00', '2026-10-17 20:00:00', '2026-09-17 20:00:00'
    UNION ALL SELECT 'NEXZ 1ST ASIA TOUR 〈SAUCIN’ THE WORLD〉', 'CONCERT', 'poster/poster_main_nexz_1st_asia_saucin_world.gif', 'NEXZ 1ST ASIA TOUR 〈SAUCIN’ THE WORLD〉', 'AGE_7', 'ON_SALE', '2026-10-17 18:00:00', '2026-10-17 20:00:00', '2026-09-16 20:00:00'
    UNION ALL SELECT 'ano LIVE in SEOUL, KOREA 2026', 'CONCERT', 'poster/poster_main_ano_seoul_korea_2026.gif', 'ano LIVE in SEOUL, KOREA 2026', 'AGE_7', 'ON_SALE', '2026-10-17 18:00:00', '2026-10-17 19:30:00', '2026-07-21 20:00:00'
    UNION ALL SELECT '2026 이승기 콘서트 〈기승전 : 樂〉', 'CONCERT', 'poster/poster_main_iseunggi_giseungjeon.gif', '2026 이승기 콘서트 〈기승전 : 樂〉', 'AGE_7', 'ON_SALE', '2026-10-23 18:00:00', '2026-10-23 20:00:00', '2026-09-11 18:00:00'
    UNION ALL SELECT '조슈아 레드먼 쿼텟 내한공연', 'CONCERT', 'poster/poster_main_josyua_redeumeon_kwotet.gif', 'Words Fall Short', 'AGE_7', 'ON_SALE', '2026-10-23 19:30:00', '2026-10-23 21:00:00', '2026-06-25 10:00:00'
    UNION ALL SELECT '강원 RED FRYS 2026 - 정규티켓', 'CONCERT', 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', '강원 RED FRYS 2026 - 정규티켓', 'ALL', 'ON_SALE', '2026-10-24 15:30:00', '2026-10-24 22:00:00', '2026-08-31 14:00:00'
    UNION ALL SELECT '2026 김수희 전국투어 콘서트 : 우리 다시, 김수희 - 광양', 'CONCERT', 'poster/poster_main_gimsuhui_uri_dasi_gimsuhui_gwangyang.gif', '2026 김수희 전국투어 콘서트 : 우리 다시, 김수희 - 광양', 'AGE_7', 'ON_SALE', '2026-10-24 18:00:00', '2026-10-24 20:00:00', '2026-08-27 11:00:00'
    UNION ALL SELECT '2026 심규선 단독 콘서트［SANCTUARY］', 'CONCERT', 'poster/poster_main_simgyuseon_sanctuary.gif', '2026 심규선 단독 콘서트［SANCTUARY］', 'AGE_7', 'ON_SALE', '2026-10-24 18:00:00', '2026-10-24 20:30:00', '2026-09-09 20:00:00'
    UNION ALL SELECT '벤슨 분 내한공연', 'CONCERT', 'poster/poster_main_benseun_bun.gif', 'Benson Boone: Wanted Man Tour in Seoul', 'ALL', 'ON_SALE', '2026-10-26 20:00:00', '2026-10-26 22:00:00', '2026-07-21 12:00:00'
    UNION ALL SELECT '키퍼 (Kiefer) 내한공연', 'CONCERT', 'poster/poster_main_kipeo_kiefer.gif', 'Kiefer - Live in Seoul', 'ALL', 'ON_SALE', '2026-10-28 20:00:00', '2026-10-28 22:00:00', '2026-09-04 12:00:00'
    UNION ALL SELECT '2026 김재환 콘서트 ［여백:餘白］', 'CONCERT', 'poster/poster_main_gimjaehwan_yeobaek.gif', '2026 김재환 콘서트 ［여백:餘白］', 'AGE_7', 'ON_SALE', '2026-10-31 18:00:00', '2026-10-31 20:00:00', '2026-09-09 20:00:00'
    UNION ALL SELECT 'Nujabes Metaphorical Ensemble Live in Seoul', 'CONCERT', 'poster/poster_main_nujabes_metaphorical_ensemble_seoul.gif', '누자베스 메타포리컬 앙상블', 'ALL', 'ON_SALE', '2026-10-31 18:00:00', '2026-10-31 19:40:00', '2026-09-03 12:00:00'
    UNION ALL SELECT '2026 이창민 팬미팅 〈PURPLE LOUNGE〉', 'CONCERT', 'poster/poster_main_ichangmin_paenmiting_purple_lounge.gif', '2026 이창민 팬미팅 〈PURPLE LOUNGE〉', 'AGE_7', 'ON_SALE', '2026-11-01 18:00:00', '2026-11-01 19:30:00', '2026-09-18 18:00:00'
    UNION ALL SELECT '2026 KO1KEYZ 1ST FAN MEETING IN SEOUL', 'CONCERT', 'poster/poster_main_ko1keyz_1st_fan_meeting_seoul.gif', '2026 KO1KEYZ 1ST FAN MEETING IN SEOUL', 'AGE_7', 'ON_SALE', '2026-11-07 14:00:00', '2026-11-07 16:00:00', '2026-09-18 18:00:00'
    UNION ALL SELECT '［데뷔 60주년 기념공연］ 2026 남진 전국투어 콘서트 - 익산', 'CONCERT', 'poster/poster_main_debwi_60junyeon_ginyeom_2026_namjin_iksan.gif', '［데뷔 60주년 기념공연］ 2026 남진 전국투어 콘서트 - 익산', 'AGE_7', 'ON_SALE', '2026-11-07 17:00:00', '2026-11-07 19:00:00', '2026-08-21 11:00:00'
    UNION ALL SELECT '2026 까치산투어 〈여기,까치산입니다.〉 - 대전', 'CONCERT', 'poster/poster_main_kkachisan_yeogi_kkachisanipnida_daejeon.gif', '2026 까치산투어 〈여기,까치산입니다.〉 - 대전', 'AGE_7', 'SCHEDULED', '2026-11-07 19:00:00', '2026-11-07 20:30:00', '2026-09-22 19:00:00'
    UNION ALL SELECT '이은미 콘서트 with 오케스트라 : 추억이 핀다 - 청주', 'CONCERT', 'poster/poster_main_ieunmi_okeseuteura_chueoki_pinda_cheongju.gif', '이은미 콘서트 with 오케스트라 : 추억이 핀다 - 청주', 'AGE_7', 'ON_SALE', '2026-11-08 17:00:00', '2026-11-08 19:00:00', '2026-08-19 14:00:00'
    UNION ALL SELECT 'Morgenshtern Alisher World Tour Part 2 Seoul', 'CONCERT', 'poster/poster_main_morgenshtern_alisher_world_part_2_seoul.gif', 'Morgenshtern Alisher World Tour Part 2 Seoul', 'AGE_19', 'ON_SALE', '2026-11-11 20:00:00', '2026-11-11 22:00:00', '2026-07-16 12:00:00'
    UNION ALL SELECT '2026 윤종신 전국투어 콘서트 〈가을냄새〉 - 대전', 'CONCERT', 'poster/poster_main_yunjongsin_gaeulnaemsae_daejeon.gif', '2026 윤종신 전국투어 콘서트 〈가을냄새〉 - 대전', 'AGE_7', 'ON_SALE', '2026-11-14 17:00:00', '2026-11-14 19:00:00', '2026-09-09 14:00:00'
    UNION ALL SELECT '2026 김필 콘서트 〈JOURNEY〉', 'CONCERT', 'poster/poster_main_gimpil_journey.gif', '2026 김필 콘서트 〈JOURNEY〉', 'AGE_7', 'ON_SALE', '2026-11-14 18:00:00', '2026-11-14 20:00:00', '2026-09-11 19:00:00'
    UNION ALL SELECT '［대구］ 최유리 콘서트 2026 : 머무름', 'CONCERT', 'poster/poster_main_daegu_choeyuri_2026_meomureum.gif', '［대구］ 최유리 콘서트 2026 : 머무름', 'AGE_7', 'ON_SALE', '2026-11-14 18:00:00', '2026-11-14 20:00:00', '2026-09-01 20:00:00'
    UNION ALL SELECT '제시 골드 (JESSE GOLD) 내한공연', 'CONCERT', 'poster/poster_main_jesi_goldeu_jesse_gold.gif', 'Jesse Gold - Live in Seoul', 'ALL', 'ON_SALE', '2026-11-16 20:00:00', '2026-11-16 22:00:00', '2026-06-12 09:00:00'
    UNION ALL SELECT '2026-27 로이킴 LIVE TOUR ［R:O:Y］ in SEOUL', 'CONCERT', 'poster/poster_main_roikim_r_o_y_seoul.gif', '2026-27 로이킴 LIVE TOUR ［R:O:Y］ in SEOUL', 'AGE_7', 'ON_SALE', '2026-11-21 18:00:00', '2026-11-21 20:00:00', '2026-09-17 20:00:00'
    UNION ALL SELECT 'LET ME KNOW LIVE TOUR 2026-Re: Still Romance-', 'CONCERT', 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'LET ME KNOW LIVE TOUR 2026-Re: Still Romance-', 'AGE_7', 'ON_SALE', '2026-11-28 18:00:00', '2026-11-28 19:10:00', '2026-07-31 18:00:00'
    UNION ALL SELECT 'Sunny Day Service TOUR 2026 in SEOUL', 'CONCERT', 'poster/poster_main_sunny_day_service_2026_seoul.gif', 'APF CONCERTS PRESENTS', 'AGE_7', 'ON_SALE', '2026-12-03 20:00:00', '2026-12-03 22:30:00', '2026-08-13 14:00:00'
    UNION ALL SELECT 'YUURI LIVE 2026 IN SEOUL', 'CONCERT', 'poster/poster_main_yuuri_2026_seoul.gif', 'YUURI LIVE 2026 IN SEOUL', 'AGE_7', 'ON_SALE', '2026-12-05 18:00:00', '2026-12-05 19:30:00', '2026-07-31 20:00:00'
    UNION ALL SELECT '카키 내한공연 (Khaki ONE-MAN Live in Seoul)', 'CONCERT', 'poster/poster_main_kaki_khaki_one_man_seoul.gif', '카키 내한공연 (Khaki ONE-MAN Live in Seoul)', 'AGE_7', 'ON_SALE', '2026-12-05 19:00:00', '2026-12-05 20:30:00', '2026-09-16 18:00:00'
    UNION ALL SELECT '칼리드 내한공연', 'CONCERT', 'poster/poster_main_kalrideu.gif', 'Khalid: It''s Always Summer Somewhere Tour in Seoul', 'AGE_12', 'ON_SALE', '2026-12-05 19:00:00', '2026-12-05 21:00:00', '2026-07-16 12:00:00'
    UNION ALL SELECT 'FKJ 내한공연', 'CONCERT', 'poster/poster_main_fkj.gif', 'FKJ - Tyber Tour in Korea', 'AGE_12', 'ON_SALE', '2026-12-06 19:00:00', '2026-12-06 21:00:00', '2026-07-07 12:00:00'
    UNION ALL SELECT '2026 KWON JIN AH LIVE TOUR ‘THIS WINTER’ IN DAEGU', 'CONCERT', 'poster/poster_main_kwon_jin_ah_this_winter_daegu.gif', '2026 KWON JIN AH LIVE TOUR ‘THIS WINTER’ IN DAEGU', 'AGE_7', 'SCHEDULED', '2026-12-12 18:00:00', '2026-12-12 20:00:00', '2026-09-23 17:00:00'
    UNION ALL SELECT '2026 다이나믹 듀오 단독 콘서트 “가끔씩 오래 보자” - 부산', 'CONCERT', 'poster/poster_main_dainamik_dyuo_gakkeumssik_orae_boja_busan.gif', '2026 다이나믹 듀오 단독 콘서트 “가끔씩 오래 보자” - 부산', 'AGE_7', 'SCHEDULED', '2026-12-12 18:00:00', '2026-12-12 20:00:00', '2026-09-30 19:00:00'
    UNION ALL SELECT '2026 카즈미 타테이시 트리오 내한공연-지브리, 재즈를 만나다-(광주)', 'CONCERT', 'poster/poster_main_kajeumi_tateisi_teurio_jibeuri_jaejeureul_mannada_gwangju.gif', 'GHIBLI meets JAZZ', 'AGE_7', 'ON_SALE', '2026-12-19 17:00:00', '2026-12-19 18:40:00', '2026-07-30 12:00:00'
    UNION ALL SELECT '마룬5 내한공연', 'CONCERT', 'poster/poster_main_marun5.gif', 'Maroon 5 Asia 2027 in Seoul', 'AGE_12', 'ON_SALE', '2027-01-27 20:00:00', '2027-01-27 22:00:00', '2026-08-14 12:00:00'
    UNION ALL SELECT '브루노 마스 내한공연', 'CONCERT', 'poster/poster_main_beuruno_maseu.gif', 'Bruno Mars - The Romantic Tour', 'AGE_7', 'ON_SALE', '2027-05-21 19:45:00', '2027-05-21 21:45:00', '2026-09-16 12:00:00'
) m
LEFT JOIN concert c ON c.poster_image_key = m.poster_image_key
WHERE c.concert_id IS NULL;

-- concert_artist --------------------------------------------------
-- 기존 (concert_id, artist_id) 연결은 건너뛴다. (이미 연결된 동일한 쌍을 중복으로 넣지 않는다는것)
INSERT INTO concert_artist (concert_id, artist_id, created_at, updated_at)
SELECT c.concert_id, a.artist_id, NOW(6), NOW(6)
FROM (
    SELECT 'poster/poster_main_key_b_day_party_keydult_club.gif' AS poster_image_key, 'KEY' AS artist_name
    UNION ALL SELECT 'poster/poster_main_takuya_kimura_2026_checkpoint_seoul.gif', 'TAKUYA KIMURA'
    UNION ALL SELECT 'poster/poster_main_gimjanghun_wonmaensyo_jeju.gif', '김장훈'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '김광진'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '김장훈'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '볼빨간사춘기'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '산다라박'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '선우정아'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '소수빈'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '홍이삭'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '송소희'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '추다혜'
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', '앙상블 시나위'
    UNION ALL SELECT 'poster/poster_main_leo_muse_fanmeeting_take_un_play_leo.gif', 'LEO MUSE'
    UNION ALL SELECT 'poster/poster_main_honggyeongmin_10wolui_maedalriseuteu.gif', '홍경민'
    UNION ALL SELECT 'poster/poster_main_sandeul_baramgyeol.gif', '산들'
    UNION ALL SELECT 'poster/poster_main_team_blaze_way_encore_kspo_dome.gif', '＆TEAM'
    UNION ALL SELECT 'poster/poster_main_reini.gif', '레이니'
    UNION ALL SELECT 'poster/poster_main_jogwanu_music_gaeului_gijeok_bucheon.gif', '조관우'
    UNION ALL SELECT 'poster/poster_main_pentagon_10th_anniversary_101010_seoul.gif', 'PENTAGON'
    UNION ALL SELECT 'poster/poster_main_chalri_puseu.gif', '찰리 푸스'
    UNION ALL SELECT 'poster/poster_main_busan_2026_jangyunjeong_master.gif', '장윤정'
    UNION ALL SELECT 'poster/poster_main_gimdongryul_oraedoen_norae.gif', '김동률'
    UNION ALL SELECT 'poster/poster_main_illit_press_start_encore_korea.gif', 'ILLIT'
    UNION ALL SELECT 'poster/poster_main_nexz_1st_asia_saucin_world.gif', 'NEXZ'
    UNION ALL SELECT 'poster/poster_main_ano_seoul_korea_2026.gif', 'ano'
    UNION ALL SELECT 'poster/poster_main_iseunggi_giseungjeon.gif', '이승기'
    UNION ALL SELECT 'poster/poster_main_josyua_redeumeon_kwotet.gif', '조슈아 레드먼 쿼텟'
    UNION ALL SELECT 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', '다이나믹 듀오'
    UNION ALL SELECT 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', 'Minos (마이노스)'
    UNION ALL SELECT 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', '허클베리피'
    UNION ALL SELECT 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', '범키'
    UNION ALL SELECT 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', '한해'
    UNION ALL SELECT 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', '치타'
    UNION ALL SELECT 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', '그리'
    UNION ALL SELECT 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', '슬리피'
    UNION ALL SELECT 'poster/poster_main_gimsuhui_uri_dasi_gimsuhui_gwangyang.gif', '김수희'
    UNION ALL SELECT 'poster/poster_main_simgyuseon_sanctuary.gif', '심규선'
    UNION ALL SELECT 'poster/poster_main_benseun_bun.gif', '벤슨 분'
    UNION ALL SELECT 'poster/poster_main_kipeo_kiefer.gif', '키퍼'
    UNION ALL SELECT 'poster/poster_main_gimjaehwan_yeobaek.gif', '김재환'
    UNION ALL SELECT 'poster/poster_main_nujabes_metaphorical_ensemble_seoul.gif', 'Nujabes Metaphorical Ensemble'
    UNION ALL SELECT 'poster/poster_main_ichangmin_paenmiting_purple_lounge.gif', '이창민'
    UNION ALL SELECT 'poster/poster_main_ko1keyz_1st_fan_meeting_seoul.gif', '코이키즈(KO1KEYZ)'
    UNION ALL SELECT 'poster/poster_main_debwi_60junyeon_ginyeom_2026_namjin_iksan.gif', '남진'
    UNION ALL SELECT 'poster/poster_main_kkachisan_yeogi_kkachisanipnida_daejeon.gif', '까치산'
    UNION ALL SELECT 'poster/poster_main_ieunmi_okeseuteura_chueoki_pinda_cheongju.gif', '이은미'
    UNION ALL SELECT 'poster/poster_main_morgenshtern_alisher_world_part_2_seoul.gif', 'Morgenshtern Alisher'
    UNION ALL SELECT 'poster/poster_main_yunjongsin_gaeulnaemsae_daejeon.gif', '윤종신'
    UNION ALL SELECT 'poster/poster_main_gimpil_journey.gif', '김필'
    UNION ALL SELECT 'poster/poster_main_daegu_choeyuri_2026_meomureum.gif', '최유리'
    UNION ALL SELECT 'poster/poster_main_jesi_goldeu_jesse_gold.gif', '제시 골드'
    UNION ALL SELECT 'poster/poster_main_roikim_r_o_y_seoul.gif', '로이킴'
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'LET ME KNOW'
    UNION ALL SELECT 'poster/poster_main_sunny_day_service_2026_seoul.gif', 'Sunny Day Service'
    UNION ALL SELECT 'poster/poster_main_yuuri_2026_seoul.gif', 'YUURI'
    UNION ALL SELECT 'poster/poster_main_kaki_khaki_one_man_seoul.gif', '카키'
    UNION ALL SELECT 'poster/poster_main_kalrideu.gif', '칼리드'
    UNION ALL SELECT 'poster/poster_main_fkj.gif', 'FKJ'
    UNION ALL SELECT 'poster/poster_main_kwon_jin_ah_this_winter_daegu.gif', 'KWON JIN AH'
    UNION ALL SELECT 'poster/poster_main_dainamik_dyuo_gakkeumssik_orae_boja_busan.gif', '다이나믹 듀오'
    UNION ALL SELECT 'poster/poster_main_kajeumi_tateisi_teurio_jibeuri_jaejeureul_mannada_gwangju.gif', '마오 스즈키'
    UNION ALL SELECT 'poster/poster_main_kajeumi_tateisi_teurio_jibeuri_jaejeureul_mannada_gwangju.gif', '카즈미 타테이시'
    UNION ALL SELECT 'poster/poster_main_kajeumi_tateisi_teurio_jibeuri_jaejeureul_mannada_gwangju.gif', '시노부 사토'
    UNION ALL SELECT 'poster/poster_main_marun5.gif', '마룬5'
    UNION ALL SELECT 'poster/poster_main_beuruno_maseu.gif', '브루노 마스'
) m
JOIN concert c ON c.poster_image_key = m.poster_image_key
JOIN artist  a ON a.artist_name      = m.artist_name
LEFT JOIN concert_artist ca ON ca.concert_id = c.concert_id AND ca.artist_id = a.artist_id
WHERE ca.concert_artist_id IS NULL;

-- concert_image ---------------------------------------------------
-- image_key 는 --images 로 내려받은 파일의 경로와 같다.
-- unique 가 없어 (concert_id, image_key) 로 직접 걸러 낸다.
INSERT INTO concert_image (concert_id, image_key, purpose, sort_order, created_at, updated_at)
SELECT c.concert_id, m.image_key, 'DETAIL', m.sort_order, NOW(6), NOW(6)
FROM (
    SELECT 'poster/poster_main_key_b_day_party_keydult_club.gif' AS poster_image_key, 'detail/poster_detail_key_b_day_party_keydult_club_0.jpg' AS image_key, 0 AS sort_order
    UNION ALL SELECT 'poster/poster_main_takuya_kimura_2026_checkpoint_seoul.gif', 'detail/poster_detail_takuya_kimura_2026_checkpoint_seoul_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_takuya_kimura_2026_checkpoint_seoul.gif', 'detail/poster_detail_takuya_kimura_2026_checkpoint_seoul_1.jpg', 1
    UNION ALL SELECT 'poster/poster_main_takuya_kimura_2026_checkpoint_seoul.gif', 'detail/poster_detail_takuya_kimura_2026_checkpoint_seoul_2.jpg', 2
    UNION ALL SELECT 'poster/poster_main_gimjanghun_wonmaensyo_jeju.gif', 'detail/poster_detail_gimjanghun_wonmaensyo_jeju_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_gimjanghun_wonmaensyo_jeju.gif', 'detail/poster_detail_gimjanghun_wonmaensyo_jeju_1.jpg', 1
    UNION ALL SELECT 'poster/poster_main_gimjanghun_wonmaensyo_jeju.gif', 'detail/poster_detail_gimjanghun_wonmaensyo_jeju_2.jpg', 2
    UNION ALL SELECT 'poster/poster_main_gimjanghun_wonmaensyo_jeju.gif', 'detail/poster_detail_gimjanghun_wonmaensyo_jeju_3.jpg', 3
    UNION ALL SELECT 'poster/poster_main_gimjanghun_wonmaensyo_jeju.gif', 'detail/poster_detail_gimjanghun_wonmaensyo_jeju_4.jpg', 4
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', 'detail/poster_detail_chungju_pakeumyujikpeseutibeol_gugak_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_chungju_pakeumyujikpeseutibeol_gugak.gif', 'detail/poster_detail_chungju_pakeumyujikpeseutibeol_gugak_1.jpg', 1
    UNION ALL SELECT 'poster/poster_main_leo_muse_fanmeeting_take_un_play_leo.gif', 'detail/poster_detail_leo_muse_fanmeeting_take_un_play_leo_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_leo_muse_fanmeeting_take_un_play_leo.gif', 'detail/poster_detail_leo_muse_fanmeeting_take_un_play_leo_1.jpg', 1
    UNION ALL SELECT 'poster/poster_main_honggyeongmin_10wolui_maedalriseuteu.gif', 'detail/poster_detail_honggyeongmin_10wolui_maedalriseuteu_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_sandeul_baramgyeol.gif', 'detail/poster_detail_sandeul_baramgyeol_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_team_blaze_way_encore_kspo_dome.gif', 'detail/poster_detail_team_blaze_way_encore_kspo_dome_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_team_blaze_way_encore_kspo_dome.gif', 'detail/poster_detail_team_blaze_way_encore_kspo_dome_1.jpg', 1
    UNION ALL SELECT 'poster/poster_main_reini.gif', 'detail/poster_detail_reini_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_jogwanu_music_gaeului_gijeok_bucheon.gif', 'detail/poster_detail_jogwanu_music_gaeului_gijeok_bucheon_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_pentagon_10th_anniversary_101010_seoul.gif', 'detail/poster_detail_pentagon_10th_anniversary_101010_seoul_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_chalri_puseu.gif', 'detail/poster_detail_chalri_puseu_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_busan_2026_jangyunjeong_master.gif', 'detail/poster_detail_busan_2026_jangyunjeong_master_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_gimdongryul_oraedoen_norae.gif', 'detail/poster_detail_gimdongryul_oraedoen_norae_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_illit_press_start_encore_korea.gif', 'detail/poster_detail_illit_press_start_encore_korea_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_illit_press_start_encore_korea.gif', 'detail/poster_detail_illit_press_start_encore_korea_1.jpg', 1
    UNION ALL SELECT 'poster/poster_main_illit_press_start_encore_korea.gif', 'detail/poster_detail_illit_press_start_encore_korea_2.png', 2
    UNION ALL SELECT 'poster/poster_main_nexz_1st_asia_saucin_world.gif', 'detail/poster_detail_nexz_1st_asia_saucin_world_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_ano_seoul_korea_2026.gif', 'detail/poster_detail_ano_seoul_korea_2026_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_ano_seoul_korea_2026.gif', 'detail/poster_detail_ano_seoul_korea_2026_1.jpg', 1
    UNION ALL SELECT 'poster/poster_main_ano_seoul_korea_2026.gif', 'detail/poster_detail_ano_seoul_korea_2026_2.jpg', 2
    UNION ALL SELECT 'poster/poster_main_ano_seoul_korea_2026.gif', 'detail/poster_detail_ano_seoul_korea_2026_3.jpg', 3
    UNION ALL SELECT 'poster/poster_main_ano_seoul_korea_2026.gif', 'detail/poster_detail_ano_seoul_korea_2026_4.jpg', 4
    UNION ALL SELECT 'poster/poster_main_iseunggi_giseungjeon.gif', 'detail/poster_detail_iseunggi_giseungjeon_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_josyua_redeumeon_kwotet.gif', 'detail/poster_detail_josyua_redeumeon_kwotet_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_gangwon_red_frys_2026_jeonggyutiket.gif', 'detail/poster_detail_gangwon_red_frys_2026_jeonggyutiket_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_gimsuhui_uri_dasi_gimsuhui_gwangyang.gif', 'detail/poster_detail_gimsuhui_uri_dasi_gimsuhui_gwangyang_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_simgyuseon_sanctuary.gif', 'detail/poster_detail_simgyuseon_sanctuary_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_benseun_bun.gif', 'detail/poster_detail_benseun_bun_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_kipeo_kiefer.gif', 'detail/poster_detail_kipeo_kiefer_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_gimjaehwan_yeobaek.gif', 'detail/poster_detail_gimjaehwan_yeobaek_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_nujabes_metaphorical_ensemble_seoul.gif', 'detail/poster_detail_nujabes_metaphorical_ensemble_seoul_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_ichangmin_paenmiting_purple_lounge.gif', 'detail/poster_detail_ichangmin_paenmiting_purple_lounge_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_ichangmin_paenmiting_purple_lounge.gif', 'detail/poster_detail_ichangmin_paenmiting_purple_lounge_1.jpg', 1
    UNION ALL SELECT 'poster/poster_main_ichangmin_paenmiting_purple_lounge.gif', 'detail/poster_detail_ichangmin_paenmiting_purple_lounge_2.jpg', 2
    UNION ALL SELECT 'poster/poster_main_ko1keyz_1st_fan_meeting_seoul.gif', 'detail/poster_detail_ko1keyz_1st_fan_meeting_seoul_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_debwi_60junyeon_ginyeom_2026_namjin_iksan.gif', 'detail/poster_detail_debwi_60junyeon_ginyeom_2026_namjin_iksan_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_kkachisan_yeogi_kkachisanipnida_daejeon.gif', 'detail/poster_detail_kkachisan_yeogi_kkachisanipnida_daejeon_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_ieunmi_okeseuteura_chueoki_pinda_cheongju.gif', 'detail/poster_detail_ieunmi_okeseuteura_chueoki_pinda_cheongju_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_morgenshtern_alisher_world_part_2_seoul.gif', 'detail/poster_detail_morgenshtern_alisher_world_part_2_seoul_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_yunjongsin_gaeulnaemsae_daejeon.gif', 'detail/poster_detail_yunjongsin_gaeulnaemsae_daejeon_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_gimpil_journey.gif', 'detail/poster_detail_gimpil_journey_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_daegu_choeyuri_2026_meomureum.gif', 'detail/poster_detail_daegu_choeyuri_2026_meomureum_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_jesi_goldeu_jesse_gold.gif', 'detail/poster_detail_jesi_goldeu_jesse_gold_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_roikim_r_o_y_seoul.gif', 'detail/poster_detail_roikim_r_o_y_seoul_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_1.jpg', 1
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_2.jpg', 2
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_3.jpg', 3
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_4.jpg', 4
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_5.jpg', 5
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_6.jpg', 6
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_7.jpg', 7
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_8.jpg', 8
    UNION ALL SELECT 'poster/poster_main_let_me_know_2026_re_still_romance.gif', 'detail/poster_detail_let_me_know_2026_re_still_romance_9.jpg', 9
    UNION ALL SELECT 'poster/poster_main_sunny_day_service_2026_seoul.gif', 'detail/poster_detail_sunny_day_service_2026_seoul_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_yuuri_2026_seoul.gif', 'detail/poster_detail_yuuri_2026_seoul_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_kaki_khaki_one_man_seoul.gif', 'detail/poster_detail_kaki_khaki_one_man_seoul_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_kalrideu.gif', 'detail/poster_detail_kalrideu_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_fkj.gif', 'detail/poster_detail_fkj_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_kwon_jin_ah_this_winter_daegu.gif', 'detail/poster_detail_kwon_jin_ah_this_winter_daegu_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_dainamik_dyuo_gakkeumssik_orae_boja_busan.gif', 'detail/poster_detail_dainamik_dyuo_gakkeumssik_orae_boja_busan_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_kajeumi_tateisi_teurio_jibeuri_jaejeureul_mannada_gwangju.gif', 'detail/poster_detail_kajeumi_tateisi_teurio_jibeuri_jaejeureul_mannada_gwangju_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_marun5.gif', 'detail/poster_detail_marun5_0.jpg', 0
    UNION ALL SELECT 'poster/poster_main_beuruno_maseu.gif', 'detail/poster_detail_beuruno_maseu_0.jpg', 0
) m
JOIN concert c ON c.poster_image_key = m.poster_image_key
LEFT JOIN concert_image ci
       ON ci.concert_id = c.concert_id AND ci.image_key = m.image_key
WHERE ci.concert_image_id IS NULL;
