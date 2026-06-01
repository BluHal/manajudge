# manajudge — immagine per Hugging Face Spaces (SDK: docker).
# Server Node a lunga vita: better-sqlite3 + sqlite-vec (nativi) e inferenza ONNX in-process.
FROM node:22-slim

# Toolchain per compilare l'addon nativo di better-sqlite3.
RUN apt-get update && apt-get install -y --no-install-recommends \
	python3 make g++ \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache del modello di embedding: cartella fissa e scrivibile, dentro l'immagine.
ENV TRANSFORMERS_CACHE=/app/.hf-cache
RUN mkdir -p /app/.hf-cache && chmod 777 /app/.hf-cache

# Dipendenze (con cache dei layer: prima solo i manifest).
COPY package*.json ./
RUN npm ci

# Codice + DB prefabbricato (data/judge.db arriva via Git LFS).
COPY . .

# "Cuoce" i pesi del modello nell'immagine: niente download al primo avvio.
RUN npx tsx scripts/warmup-model.ts

# Build SvelteKit (adapter-node -> ./build).
RUN npm run build

ENV NODE_ENV=production
# HF Spaces instrada il traffico verso questa porta (vedi app_port nel README).
ENV PORT=7860
EXPOSE 7860

CMD ["node", "build"]
