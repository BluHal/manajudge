import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
	// Vite non espone le var non-VITE_ a process.env: le carichiamo noi così il codice
	// server (es. GEMINI_API_KEY in src/lib/server/llm/gemini.ts) le legge anche in dev.
	Object.assign(process.env, loadEnv(mode, process.cwd(), ''));

	return {
		plugins: [sveltekit()],
		// Moduli nativi / pesanti solo-server: non vanno inclusi nel bundle SSR.
		ssr: {
			external: ['better-sqlite3', 'sqlite-vec', '@huggingface/transformers']
		}
	};
});
