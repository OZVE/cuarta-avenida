FROM oven/bun:1.3.8-alpine AS base

WORKDIR /app

# ── Dependencias ─────────────────────────────────────────────────────────────
FROM base AS deps

COPY package.json bun.lock turbo.json ./
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

# Instalar con concurrencia limitada para reducir pico de memoria
RUN bun install --concurrent-scripts 1

# ── Build ─────────────────────────────────────────────────────────────────────
FROM deps AS builder

COPY . .

# 1. types
RUN cd packages/types && bun run build

# 2. core-plugin
RUN cd packages/core-plugin && bun run build

# 3. API - usar node para medusa build (bun tiene incompatibilidades con mikro-orm decorators)
RUN cd apps/api && node /app/node_modules/.bin/medusa build

# ── Imagen final ──────────────────────────────────────────────────────────────
FROM oven/bun:1.3.8-alpine AS runner

WORKDIR /app

COPY --from=builder /app/package.json           ./
COPY --from=builder /app/bun.lock               ./
COPY --from=builder /app/node_modules           ./node_modules
COPY --from=builder /app/apps/api               ./apps/api
COPY --from=builder /app/packages/types         ./packages/types
COPY --from=builder /app/packages/core-plugin   ./packages/core-plugin

WORKDIR /app/apps/api

EXPOSE 9000

COPY scripts/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
