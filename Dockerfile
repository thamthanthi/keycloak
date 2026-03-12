FROM eclipse-temurin:21-jdk AS builder

WORKDIR /src
COPY . .

RUN apt-get update && \
    apt-get install -y curl git ca-certificates && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g pnpm

RUN echo "=== versions ===" && \
    java -version && \
    node -v && \
    npm -v && \
    pnpm -v

RUN chmod +x mvnw && \
    echo "=== start maven build ===" && \
    ./mvnw -pl quarkus/deployment,quarkus/dist \
      -am \
      -DskipTests \
      -DskipProtoLock=true \
      clean install -e -X

RUN echo "=== dist target ===" && \
    ls -lah quarkus/dist/target && \
    find quarkus/dist/target -maxdepth 1 -type f | sort

RUN ARTIFACT="$(find quarkus/dist/target -maxdepth 1 -type f -name 'keycloak-*.tar.gz' | head -n 1)" && \
    test -n "$ARTIFACT" && \
    mkdir -p /out && \
    cp "$ARTIFACT" /out/keycloak.tar.gz

FROM eclipse-temurin:21-jre

ENV KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true

WORKDIR /opt/keycloak

COPY --from=builder /out/keycloak.tar.gz /tmp/keycloak.tar.gz

RUN mkdir -p /opt/keycloak && \
    tar -xzf /tmp/keycloak.tar.gz -C /opt/keycloak --strip-components=1 && \
    rm -f /tmp/keycloak.tar.gz && \
    chmod +x /opt/keycloak/bin/kc.sh

EXPOSE 8080 9000

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start"]
