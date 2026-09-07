-- 로컬 개발용 시드 데이터.
--
-- ddl-auto 가 create-drop 이라 앱을 내릴 때 테이블이 사라진다. 이 스크립트는
-- Hibernate 가 스키마를 만든 뒤에 실행돼(defer-datasource-initialization) 매 기동마다
-- 같은 시드를 다시 채운다. local 프로필에서만 동작한다. (application-local.yml 참고)
--
-- 아티스트는 아직 등록 API 가 없어 여기서 직접 넣는다. 등록 API 가 생기면 이 파일은 지운다.
-- artist_id 를 명시해 두면 http-client.env.json 의 artistId1 / artistId2 가 항상 유효하다.
-- created_at / updated_at 은 NOT NULL 인데 raw SQL 은 JPA Auditing 을 타지 않아 직접 넣는다.
INSERT IGNORE INTO artist (artist_id, artist_name, profile_image, created_at, updated_at)
VALUES (1, '아이유', 'artist/1/profile.png', NOW(6), NOW(6)),
       (2, '박효신', 'artist/2/profile.png', NOW(6), NOW(6));
