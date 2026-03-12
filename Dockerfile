FROM eclipse-temurin:21-jdk AS builder

WORKDIR /build
COPY . .

RUN apt-get update && \
    apt-get install -y curl git ca-certificates nodejs npm unzip && \
    npm install -g pnpm

RUN chmod +x mvnw && \
    ./mvnw -pl quarkus/deployment,quarkus/dist \
      -am \
      -DskipTests \
      -DskipProtoLock=true \
      clean install

RUN ARTIFACT=$(ls quarkus/dist/target/keycloak-*.zip | head -n1) && \
    mkdir -p /out && \
    cp "$ARTIFACT" /out/keycloak.zip

FROM eclipse-temurin:21-jre

WORKDIR /opt

COPY --from=builder /out/keycloak.zip /tmp/keycloak.zip

RUN apt-get update && apt-get install -y unzip && \
    unzip /tmp/keycloak.zip -d /opt && \
    mv /opt/keycloak-* /opt/keycloak && \
    mkdir -p /opt/keycloak/data/tmp && \
    chmod +x /opt/keycloak/bin/kc.sh && \
    chown -R 1000:0 /opt/keycloak && \
    chmod -R g=u /opt/keycloak && \
    rm -f /tmp/keycloak.zip

ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_DB=postgres

WORKDIR /opt/keycloak

RUN /opt/keycloak/bin/kc.sh build

EXPOSE 8080 9000

USER 1000

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start","--optimized"]
