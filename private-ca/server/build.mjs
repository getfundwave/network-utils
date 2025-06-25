import { build } from 'esbuild';

await build({
  entryPoints: ['index_lambda.js'],
  bundle: true,
  platform: 'node',
  target: 'node18',
  outfile: 'dist/index_lambda.js',
  format: 'cjs',
  external: [],
});