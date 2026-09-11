-- 로컬 개발용 시드 데이터.
--
-- ddl-auto 가 create-drop 이라 앱을 내릴 때 테이블이 사라진다. 이 스크립트는
-- Hibernate 가 스키마를 만든 뒤에 실행돼(defer-datasource-initialization) 매 기동마다
-- 같은 시드를 다시 채운다. local 프로필에서만 동작한다. (application-local.yml 참고)
--
-- 아티스트는 아직 등록 API 가 없어 여기서 직접 넣는다. 등록 API 가 생기면 이 파일은 지운다.
-- artist_id 를 명시해 두면 http-client.env.json 의 artistId1 / artistId2 가 항상 유효하다.
-- created_at / updated_at 은 NOT NULL 인데 raw SQL 은 JPA Auditing 을 타지 않아 직접 넣는다.
--
-- 여기가 로컬 아티스트의 원본이다. 공연을 채우는 LocalDataSeeder 가 이 id 를 그대로 참조하므로
-- id 나 이름을 바꾸면 그쪽 CONCERT_SEEDS 도 함께 봐야 한다. v0 스텁(StubFixtures.ARTISTS)도
-- 같은 값을 따로 들고 있어, 로컬에서 v0 와 v1 을 오가도 같은 아티스트가 나온다.
-- profile_image 는 src/main/resources/static 에 실제로 있는 파일 key 다.
INSERT IGNORE INTO artist (artist_id, artist_name, profile_image, created_at, updated_at)
VALUES (1, '김필', 'artist/artist_kim_feel.jpg', NOW(6), NOW(6)),
       (2, '이승기', 'artist/artist_lee_s.jpg', NOW(6), NOW(6)),
       (3, '로이킴', 'artist/artist_roykim.jpg', NOW(6), NOW(6)),
       (4, 'Bruno Mars', 'artist/artist_bruno_mars.jpg', NOW(6), NOW(6));
