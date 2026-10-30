import { readFile, writeFile, mkdir, cp, access, readdir, rm } from 'node:fs/promises';
import { resolve, join, basename, extname } from 'node:path';
import { createHash } from 'node:crypto';

const root = resolve(import.meta.dirname, '..');
const output = join(root, 'build/site');
const publicOnly = process.argv.includes('--public-only');
await rm(output, { recursive: true, force: true });
await mkdir(join(output, 'site-assets'), { recursive: true });
if (!publicOnly) {
  const appIndex = await readFile(join(root, 'build/web/index.html'), 'utf8');
  if (!appIndex.includes('<base href="/app/">')) throw new Error('Build Flutter with --base-href /app/ before assembling.');
  await access(join(root, 'build/web/flutter_bootstrap.js'));
  await cp(join(root, 'build/web'), join(output, 'app'), { recursive: true });
}
async function asset(path) {
  const data = await readFile(join(root, path));
  const extension = extname(path);
  const name = basename(path, extension);
  const hash = createHash('sha256').update(data).digest('hex').slice(0, 12);
  const target = `${name}.${hash}${extension}`;
  await writeFile(join(output, 'site-assets', target), data);
  return `/site-assets/${target}`;
}
async function webp(path) {
  const data = await readFile(join(root, path));
  if (data.toString('ascii', 0, 4) !== 'RIFF' || data.toString('ascii', 8, 12) !== 'WEBP') {
    throw new Error(`${path} is not an actual WebP file. Convert the file; do not just rename it.`);
  }
  return asset(path);
}
const options = await readFile(join(root, 'lib/firebase_options.dart'), 'utf8');
const webOptions = options.match(/static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\);/)?.[1];
function option(name) {
  const value = webOptions?.match(new RegExp(`${name}:\\s*'([^']+)'`))?.[1];
  if (!value) throw new Error(`Missing public Firebase web setting: ${name}`);
  return value;
}
const config = {
  projectId: option('projectId'), apiKey: option('apiKey'),
  treeModule: await asset('public-site/tree-data.js'),
  leafletJs: await asset('public-site/vendor/leaflet.js'),
  leafletCss: await asset('public-site/vendor/leaflet.css'),
};
const replacements = {
  '__HERO_MOBILE__': await webp('assets/image/hero_cirebon_mobile.webp'),
  '__HERO_DESKTOP__': await webp('assets/image/hero_cirebon_desktop.webp'),
  '__LOGO__': await webp('public-site/assets/logo.webp'),
  '__CSS__': await asset('public-site/site.css'),
  '__JS__': await asset('public-site/site.js'),
  '__CONFIG__': JSON.stringify(config).replaceAll('<', '\\u003c'),
};
let html = await readFile(join(root, 'public-site/index.html'), 'utf8');
for (const [key, value] of Object.entries(replacements)) html = html.replaceAll(key, value);
if (/__[A-Z_]+__/.test(html)) throw new Error('Unresolved HTML asset token');
await writeFile(join(output, 'index.html'), html);
for (const file of ['robots.txt', 'sitemap.xml', '404.html', 'flutter_service_worker.js', 'manifest.json']) await cp(join(root, 'public-site', file), join(output, file));
await cp(join(root, 'web/favicon.png'), join(output, 'favicon.png'));
await cp(join(root, 'web/favicon-pohon.png'), join(output, 'favicon-pohon.png'));
await cp(join(root, 'web/icons'), join(output, 'icons'), { recursive: true });
await cp(join(root, 'public-site/vendor/LEAFLET-LICENSE.txt'), join(output, 'site-assets/LEAFLET-LICENSE.txt'));
console.log(`Public site assembled. ${publicOnly ? 'Public preview only; Flutter app has NOT been built.' : 'Flutter app retained at /app/.'}`);
console.log(`Public asset count: ${(await readdir(join(output, 'site-assets'))).length}`);
