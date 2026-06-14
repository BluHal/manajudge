# syntax=docker/dockerfile:1
#
# manajudge Backend — immagine multi-arch (gira anche su ARM64: Oracle Always Free A1).
# Vedi docs/deploy-oracle.md. La VM è warm e stateful (ADR 0002):
#  - il DB SQLite vive su un volume persistente montato su /app/data (NON è nell'immagine);
#  - il modello di embedding è "baked" nell'immagine, così il boot è caldo (niente download).

ARG NODE_VERSION=24-bookworm-slim

# --- builder: toolchain nativa + build SvelteKit + prewarm del modello ---
FROM node:${NODE_VERSION} AS builder
WORKDIR /app

# Build deps per i moduli nativi (better-sqlite3): python3 + g++ + make.
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json .npmrc ./
RUN npm ci

COPY . .
RUN npm run build

# Scarica il modello di embedding nella cache baked nell'immagine.
ENV MODEL_CACHE_DIR=/app/.model-cache
RUN npm run prewarm

# --- prod-deps: solo dipendenze di produzione, compilate per questa arch ---
FROM node:${NODE_VERSION} AS prod-deps
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json .npmrc ./
RUN npm ci --omit=dev

# --- runner: immagine snella, niente toolchain ---
FROM node:${NODE_VERSION} AS runner
WORKDIR /app
ENV NODE_ENV=production \
    MODEL_CACHE_DIR=/app/.model-cache \
    DB_PATH=/app/data/judge.db \
    HOST=0.0.0.0 \
    PORT=3000

COPY package.json package-lock.json .npmrc ./
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=builder /app/build ./build
COPY --from=builder /app/.model-cache ./.model-cache

EXPOSE 3000

# Il DB SQLite arriva dal volume montato su /app/data (vedi runbook).
VOLUME ["/app/data"]

# Readiness della VM warm: /api/health verifica DB + scalda il modello in RAM.
HEALTHCHECK --interval=30s --timeout=30s --start-period=180s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "build/index.js"]
