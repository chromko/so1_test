FROM maven:3.3.9 as build
WORKDIR /tmp
COPY . .
RUN set -xe;  \
    mvn -B clean; \
    mvn -B compile; \
    mvn -B package

FROM openjdk:8
WORKDIR /app
COPY --from=build /tmp/target/users-mysql.jar /app/
EXPOSE 8086
ENTRYPOINT ["java", "-jar", "users-mysql.jar"]
