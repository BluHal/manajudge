import { defineConfig } from 'vitest/config';

// Config di test isolata dal plugin SvelteKit: i test coprono la logica server
// (retrieval, preprocess) che gira in Node, non i componenti Svelte.
export default defineConfig({
	test: {
		environment: 'node',
		globals: true,
		include: ['src/**/*.test.ts']
	}
});
