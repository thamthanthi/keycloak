FROM eclipse-temurin:21-jdk AS builder

WORKDIR /build

# base tools layer
RUN apt-get update && \
    apt-get install -y curl git ca-certificates nodejs npm unzip && \
    npm install -g pnpm

# copy maven wrapper and root descriptors first
COPY mvnw ./
COPY .mvn ./.mvn
COPY pom.xml ./

# copy only files likely needed to resolve/build modules
COPY quarkus ./quarkus
COPY js ./js
COPY common ./common
COPY core ./core
COPY server-spi ./server-spi
COPY server-spi-private ./server-spi-private
COPY services ./services
COPY model ./model
COPY testsuite ./testsuite
COPY themes ./themes
COPY theme ./theme
COPY docs ./docs
COPY operator ./operator
COPY distribution ./distribution
COPY adapters ./adapters
COPY authz ./authz
COPY federation ./federation
COPY misc ./misc
COPY integration ./integration
COPY crypto ./crypto
COPY dependencies ./dependencies
COPY boms ./boms

RUN chmod +x mvnw

# Maven + pnpm cache mounts (BuildKit)
RUN --mount=type=cache,target=/root/.m2 \
    --mount=type=cache,target=/root/.local/share/pnpm/store \
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

RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/keycloak.zip /tmp/keycloak.zip

RUN unzip /tmp/keycloak.zip -d /opt && \
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

USER 1000

EXPOSE 8080 9000

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized"]
