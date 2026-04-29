import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
	const env = loadEnv(mode, process.cwd(), '');
	const backend = env.VITE_BACKEND_URL || 'http://uwbp:8080';

	return {
		plugins: [sveltekit()],
		server: {
			proxy: {
				'/api': {
					target: backend,
					changeOrigin: true
				}
			}
		}
	};
});
