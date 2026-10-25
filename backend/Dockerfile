# syntax=docker/dockerfile:1

# ---- build ---------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /workspace

COPY pom.xml ./
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q package -DskipTests

# ---- runtime -------------------------------------------------------------
FROM eclipse-temurin:17-jre

RUN useradd --system --uid 10001 --home-dir /app playground \
    && mkdir -p /app/data \
    && chown -R playground:playground /app

WORKDIR /app
COPY --from=build /workspace/target/safe-playground-backend-*.jar /app/app.jar

USER playground
EXPOSE 8086

# The default profile keeps an H2 file database and media under /app/data, so
# mounting a volume there is all that is needed for persistence.
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
