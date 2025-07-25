import { build } from 'esbuild';

await build({
  entryPoints: ['src/index_lambda.ts'],
  bundle: true,
  platform: 'node',
  target: 'node18',
  outfile: 'dist/index_lambda.js',
  format: 'cjs',
});