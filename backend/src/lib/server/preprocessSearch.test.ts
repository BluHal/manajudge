import { describe, it, expect } from 'vitest';
import type { LLMProvider } from './llm/provider.ts';
import { preprocessSearch } from './preprocessSearch.ts';

/** Provider finto: completeJSON restituisce un oggetto fissato (o lancia). */
function fakeLLM(json: unknown, throws = false): LLMProvider {
	return {
		completeJSON: async () => {
			if (throws) throw new Error('LLM down');
			return json as never;
		},
		// eslint-disable-next-line require-yield
		stream: async function* () {
			throw new Error('non usato');
		}
	};
}

describe('preprocessSearch', () => {
	it('traduce la query in intento semantico + filtri strutturati', async () => {
		const llm = fakeLLM({
			intento: 'carte che fanno ramp',
			escludi_tipi: ['Land'],
			formato: 'modern'
		});

		const out = await preprocessSearch(llm, 'carte che fanno ramp senza usare terre in modern');

		expect(out.semanticQuery).toBe('carte che fanno ramp');
		expect(out.filters).toEqual({ excludeTypes: ['Land'], legalIn: 'modern' });
	});

	it('se l\'LLM fallisce, ripiega sulla query grezza senza filtri', async () => {
		const llm = fakeLLM(null, true);

		const out = await preprocessSearch(llm, 'carte che copiano spell');

		expect(out.semanticQuery).toBe('carte che copiano spell');
		expect(out.filters).toEqual({});
	});
});
