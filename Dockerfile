FROM eclipse-temurin:21-jdk AS builder

WORKDIR /keycloak
COPY . .

RUN apt-get update && \
    apt-get install -y curl git ca-certificates nodejs npm unzip && \
    npm install -g pnpm

RUN java -version && node -v && npm -v && pnpm -v

RUN chmod +x mvnw && \
    ./mvnw -pl quarkus/deployment,quarkus/dist \
      -am \
      -DskipTests \
      -DskipProtoLock=true \
      clean install

RUN ls -lah quarkus/dist/target && \
    find quarkus/dist/target -maxdepth 1 -type f | sort && \
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
      *.tar.gz) tar -xzf "$ARTIFACT" -C /opt/keycloak ;; \
      *.zip) unzip -q "$ARTIFACT" -d /opt/keycloak ;; \
      *) echo "Unsupported artifact: $ARTIFACT" && exit 1 ;; \
    esac; \
    echo "=== extracted files ==="; \
    find /opt/keycloak -maxdepth 3 -type f | sort | head -n 200; \
    KC_PATH="$(find /opt/keycloak -type f -path '*/bin/kc.sh' | head -n 1)"; \
    test -n "$KC_PATH"; \
    KC_DIR="$(dirname "$(dirname "$KC_PATH")")"; \
    if [ "$KC_DIR" != "/opt/keycloak" ]; then \
      TMPDIR="$(mktemp -d)"; \
      cp -a "$KC_DIR"/. "$TMPDIR"/; \
      rm -rf /opt/keycloak/*; \
      cp -a "$TMPDIR"/. /opt/keycloak/; \
      rm -rf "$TMPDIR"; \
    fi; \
    test -f /opt/keycloak/bin/kc.sh; \
    chmod +x /opt/keycloak/bin/kc.sh; \
    rm -rf /tmp/keycloak-dist

EXPOSE 8080 9000

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start"]
