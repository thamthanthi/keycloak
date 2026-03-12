FROM eclipse-temurin:21-jdk AS builder

WORKDIR /keycloak
COPY . .

RUN apt-get update && \
    apt-get install -y curl git ca-certificates && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g pnpm

RUN java -version && node -v && npm -v && pnpm -v

RUN chmod +x mvnw && \
    ./mvnw -pl js -am -DskipTests -DskipProtoLock=true clean install -e -X || true

RUN cd js && \
    echo "=== package.json ===" && \
    head -n 40 package.json && \
    echo "=== pnpm install ===" && \
    pnpm install --frozen-lockfile || true && \
    echo "=== pnpm build ===" && \
    pnpm build || true
