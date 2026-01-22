# Dockerfile
# Build stage
FROM eclipse-temurin:17-jdk-alpine as build
WORKDIR /app

# Копируем файлы для кэширования зависимостей
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Скачиваем зависимости
RUN ./mvnw dependency:go-offline -B

# Копируем исходный код
COPY src src

# Собираем приложение
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Runtime stage
FROM eclipse-temurin:17-jre-alpine
VOLUME /tmp

# Аргументы для Spring Boot
ARG DEPENDENCY=/app/target/dependency
COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app

# Создаем пользователя для безопасности
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Устанавливаем healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8081/actuator/health || exit 1

# Запуск приложения
ENTRYPOINT ["java", \
            "-XX:+UseContainerSupport", \
            "-XX:MaxRAMPercentage=75.0", \
            "-Djava.security.egd=file:/dev/./urandom", \
            "-cp", "app:app/lib/*", \
            "ru.housetrade.HouseTradeApplication"]