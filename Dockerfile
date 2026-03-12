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

RUN ls -lah quarkus/dist/target

# copy artifact
RUN ARTIFACT=$(ls quarkus/dist/target/keycloak-*.zip | head -n1) && \
    mkdir -p /out && \
    cp $ARTIFACT /out/keycloak.zip


FROM eclipse-temurin:21-jre

WORKDIR /opt

COPY --from=builder /out/keycloak.zip /tmp/keycloak.zip

RUN apt-get update && apt-get install -y unzip && \
    unzip /tmp/keycloak.zip -d /opt && \
    mv /opt/keycloak-* /opt/keycloak && \
    chmod +x /opt/keycloak/bin/kc.sh && \
    rm /tmp/keycloak.zip

WORKDIR /opt/keycloak

EXPOSE 8080 9000

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start"]
