FROM gradle:8.10-jdk17 AS build
WORKDIR /home/gradle/project

COPY settings.gradle build.gradle gradle.properties gradlew ./
COPY gradle ./gradle
COPY backend/user-service/build.gradle backend/user-service/

RUN gradle --no-daemon :backend:user-service:dependencies

COPY . .
RUN gradle --no-daemon :backend:user-service:runnerJar

FROM eclipse-temurin:17-jre-jammy AS runtime
WORKDIR /app

RUN apt-get update \
    && apt-get install --no-install-recommends -y curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1001 appuser

COPY --from=build --chown=appuser:appuser \
  /home/gradle/project/backend/user-service/build/libs/*-runner.jar app.jar

USER appuser
EXPOSE 8081

HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD curl --fail --silent http://localhost:8081/api/status || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
