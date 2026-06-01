import adapter from '@sveltejs/adapter-node';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	compilerOptions: {
		// Force runes mode for the project, except for libraries. Can be removed in svelte 6.
		runes: ({ filename }) => (filename.split(/[/\\]/).includes('node_modules') ? undefined : true)
	},
	kit: {
		// adapter-node: runs as a long-lived Node server inside the Docker image we deploy
		// to Hugging Face Spaces. The app needs a real Node runtime (native better-sqlite3 +
		// sqlite-vec, plus in-process ONNX inference), so an edge/serverless adapter won't work.
		adapter: adapter()
	}
};

export default config;
