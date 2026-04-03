FROM node:20-alpine AS base

# Install bun
RUN npm install -g bun@1.3.8

WORKDIR /app

# ── Dependencias ─────────────────────────────────────────────────────────────
FROM base AS deps

# Copiar manifests del monorepo (para aprovechar cache de capas)
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
COPY integration-tests/package.json             ./integration-tests/

RUN bun install --frozen-lockfile

# ── Build ─────────────────────────────────────────────────────────────────────
FROM deps AS builder

# Copiar el codigo fuente completo
COPY . .

# 1. types
RUN cd packages/types && bun run build

# 2. core-plugin (necesita internet para codegen, requiere acceso a npm)
RUN cd packages/core-plugin && bun run build

# 3. API (medusa build)
RUN cd apps/api && bun run build

# ── Imagen final ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

RUN npm install -g bun@1.3.8

WORKDIR /app

# Copiar solo lo necesario para produccion
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
