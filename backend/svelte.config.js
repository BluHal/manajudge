import adapter from '@sveltejs/adapter-node';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	compilerOptions: {
		// Force runes mode for the project, except for libraries. Can be removed in svelte 6.
		runes: ({ filename }) => (filename.split(/[/\\]/).includes('node_modules') ? undefined : true)
	},
	kit: {
		// adapter-node: server Node standalone (`node build/index.js`) per la VM ARM warm,
		// always-on di Oracle Always Free (ADR 0002). Niente serverless scale-to-zero.
		adapter: adapter()
	}
};

export default config;
