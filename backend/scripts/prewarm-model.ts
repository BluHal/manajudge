/**
 * Scarica il modello di embedding nella cache (MODEL_CACHE_DIR) così l'immagine/volume di
 * deploy parte "warm": niente download del modello al primo boot. Eseguito in fase di build
 * dell'immagine Docker. Vedi docs/deploy-oracle.md.
 *
 * Uso: MODEL_CACHE_DIR=/app/.model-cache npm run prewarm
 */
import { embed, EMBED_MODEL } from '../src/lib/server/embeddings.ts';

console.log(`Prewarm di ${EMBED_MODEL} → ${process.env.MODEL_CACHE_DIR ?? '(cache default)'} ...`);
const vec = await embed('warm');
console.log(`OK: modello in cache, embedding dim ${vec.length}.`);
