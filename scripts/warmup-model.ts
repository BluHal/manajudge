/**
 * Scarica e mette in cache il modello di embedding. Eseguito in fase di BUILD del Docker
 * (vedi Dockerfile) per "cuocere" i pesi del modello nell'immagine: così al primo avvio
 * non c'è alcun download e i cold start restano veloci.
 */
import { embed } from '../src/lib/server/embeddings.ts';

const t0 = Date.now();
await embed('warmup');
console.log(`Modello di embedding scaricato e in cache in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
