FROM gradle:8.10-jdk17 AS build
WORKDIR /home/gradle/project

COPY settings.gradle build.gradle gradle.properties gradlew ./
COPY gradle ./gradle
COPY backend/payment-service/build.gradle backend/payment-service/

RUN gradle --no-daemon :backend:payment-service:dependencies

COPY . .
RUN gradle --no-daemon :backend:payment-service:runnerJar

FROM eclipse-temurin:17-jre-jammy AS runtime
WORKDIR /app

RUN apt-get update \
    && apt-get install --no-install-recommends -y curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1001 appuser

COPY --from=build --chown=appuser:appuser \
  /home/gradle/project/backend/payment-service/build/libs/*-runner.jar app.jar

USER appuser
EXPOSE 8082

HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD curl --fail --silent http://localhost:8082/api/status || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
