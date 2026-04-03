FROM node:20-alpine AS base

WORKDIR /app

# ── Dependencias ─────────────────────────────────────────────────────────────
FROM base AS deps

# Copiar manifests del monorepo
COPY package.json turbo.json ./
COPY apps/api/package.json                      ./apps/api/
COPY packages/types/package.json                ./packages/types/
COPY packages/core-plugin/package.json          ./packages/core-plugin/
COPY packages/cli/package.json                  ./packages/cli/
COPY packages/client/package.json               ./packages/client/
COPY packages/admin/package.json                ./packages/admin/
COPY packages/vendor/package.json               ./packages/vendor/
COPY packages/dashboard-sdk/package.json        ./packages/dashboard-sdk/
COPY packages/dashboard-shared/package.json     ./packages/dashboard-shared/
COPY packages/providers/payout-stripe-connect/package.json ./packages/providers/payout-stripe-connect/
COPY packages/registry/package.json             ./packages/registry/

# Stub para integration-tests (no va a produccion)
RUN mkdir -p integration-tests && \
    echo '{"name":"@mercurjs/integration-tests","version":"0.0.1","private":true}' \
    > integration-tests/package.json

# Instalar con npm (menor consumo de memoria que bun en entornos restringidos)
# --legacy-peer-deps evita conflictos de peers en monorepos
RUN npm install --legacy-peer-deps

# ── Build ─────────────────────────────────────────────────────────────────────
FROM deps AS builder

# Copiar el codigo fuente completo
COPY . .

# 1. types
RUN cd packages/types && npm run build

# 2. core-plugin
RUN cd packages/core-plugin && npm run build

# 3. API
RUN cd apps/api && npm run build

# ── Imagen final ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

# Copiar solo lo necesario para produccion
COPY --from=builder /app/package.json           ./
COPY --from=builder /app/node_modules           ./node_modules
COPY --from=builder /app/apps/api               ./apps/api
COPY --from=builder /app/packages/types         ./packages/types
COPY --from=builder /app/packages/core-plugin   ./packages/core-plugin

WORKDIR /app/apps/api

EXPOSE 9000

COPY scripts/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
