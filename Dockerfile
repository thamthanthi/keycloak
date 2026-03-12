FROM eclipse-temurin:21-jdk AS builder

WORKDIR /src
COPY . .

RUN chmod +x mvnw && \
    ./mvnw -pl quarkus/deployment,quarkus/dist -am -DskipTests -DskipProtoLock=true clean install && \
    ls -lah quarkus/dist/target && \
    ARTIFACT="$(find quarkus/dist/target -maxdepth 1 -type f \( -name 'keycloak-*.tar.gz' -o -name 'keycloak-*.zip' \) | head -n 1)" && \
    test -n "$ARTIFACT" && \
    mkdir -p /out && \
    cp "$ARTIFACT" /out/

FROM eclipse-temurin:21-jre

ENV KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true

WORKDIR /opt/keycloak

COPY --from=builder /out/ /tmp/keycloak-dist/

RUN set -eux; \
    ARTIFACT="$(find /tmp/keycloak-dist -type f \( -name 'keycloak-*.tar.gz' -o -name 'keycloak-*.zip' \) | head -n 1)"; \
    test -n "$ARTIFACT"; \
    mkdir -p /opt/keycloak; \
    case "$ARTIFACT" in \
      *.tar.gz) tar -xzf "$ARTIFACT" -C /opt/keycloak --strip-components=1 ;; \
      *.zip) \
        apt-get update && apt-get install -y unzip && \
        unzip -q "$ARTIFACT" -d /tmp/unzipped && \
        cp -r /tmp/unzipped/*/* /opt/keycloak/ ;; \
      *) echo "Unsupported artifact: $ARTIFACT" && exit 1 ;; \
    esac; \
    rm -rf /tmp/keycloak-dist /tmp/unzipped; \
    chmod +x /opt/keycloak/bin/kc.sh

EXPOSE 8080 9000

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start"]
