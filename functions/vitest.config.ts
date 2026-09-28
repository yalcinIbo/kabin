import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    testTimeout: 60_000,
    hookTimeout: 60_000,
    pool: 'forks',
    fileParallelism: false,
    env: {
      GCLOUD_PROJECT: 'demo-kabin',
      STORAGE_BUCKET: 'demo-kabin.appspot.com',
      TRYON_PROVIDER: 'fashn',
      MODEL3D_PROVIDER: 'hunyuan',
      MOCK_PROVIDERS: 'all',
    },
  },
});
