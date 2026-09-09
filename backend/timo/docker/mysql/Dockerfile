FROM mysql:8.0

# Windows 바인드 마운트는 world-writable 권한으로 노출되어 mysql 클라이언트가
# 보안상 설정 파일을 무시한다. 빌드 시점에 COPY 하면 정상 권한(644)으로 들어간다.
COPY conf.d/client.cnf /etc/mysql/conf.d/client.cnf
