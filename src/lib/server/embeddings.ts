import { pipeline, type FeatureExtractionPipeline } from '@huggingface/transformers';

/**
 * Modello di embedding multilingue (locale, gratuito). Mappa testo italiano e inglese
 * nello stesso spazio vettoriale, così una domanda in italiano trova regole in inglese.
 */
export const EMBED_MODEL = 'Xenova/paraphrase-multilingual-MiniLM-L12-v2';

let _extractor: Promise<FeatureExtractionPipeline> | null = null;

function getExtractor(): Promise<FeatureExtractionPipeline> {
	if (!_extractor) {
		_extractor = pipeline('feature-extraction', EMBED_MODEL);
	}
	return _extractor;
}

/** Calcola l'embedding (normalizzato) di un singolo testo. */
export async function embed(text: string): Promise<number[]> {
	const [vec] = await embedBatch([text]);
	return vec;
}

/** Calcola gli embedding di un batch di testi. Output normalizzato (cosine = dot product). */
export async function embedBatch(texts: string[]): Promise<number[][]> {
	if (texts.length === 0) return [];
	const extractor = await getExtractor();
	const output = await extractor(texts, { pooling: 'mean', normalize: true });
	return output.tolist() as number[][];
}
