# =========================
# 1. Build stage
# =========================
FROM eclipse-temurin:21-jdk-jammy AS builder

WORKDIR /app

# Gradle 관련 파일을 먼저 복사해서 dependency layer 캐싱
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./

# 현재 업로드된 gradlew의 실행 권한이 없어서 명시적으로 부여
RUN chmod +x gradlew

# 의존성 다운로드
RUN ./gradlew dependencies --no-daemon

# 소스 복사
COPY src src

# CI에서 test를 별도 수행할 예정이므로 Docker build에서는 테스트 제외
RUN ./gradlew bootJar --no-daemon -x test \
    && find build/libs -name "*.jar" ! -name "*-plain.jar" \
       -exec cp {} /app/app.jar \;


# =========================
# 2. Runtime stage
# =========================
FROM eclipse-temurin:21-jre-jammy

WORKDIR /app

COPY --from=builder /app/app.jar app.jar

# 기본 실행 환경 - 필요하면 docker run / ECS 환경변수로 덮어쓸 수 있음.
ENV SPRING_PROFILES_ACTIVE=prod

# 로그 타임스탬프용 타임존 보정(도메인 로직은 ClockConfig의 Asia/Seoul 고정이라 영향 없음).
ENV TZ=Asia/Seoul

# Wallet.createStandard()의 scrypt가 큰 힙을 요구해 t3.medium(4GiB) 기준 상한을 명시한다.
ENV JAVA_TOOL_OPTIONS="-Xms256m -Xmx1536m"

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
