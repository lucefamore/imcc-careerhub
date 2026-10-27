const fs = require('node:fs');
const path = require('node:path');

const root = __dirname;
const output = path.join(root, 'public');
const staticFiles = [
  'styles.css',
  'jobs-it.js',
  'jobs-healthcare.js',
  'jobs-business.js',
  'jobs-education.js',
  'jobs-ccje.js',
  'jobs-socialwork.js',
  'jobs-chtm.js',
  'jobs-renderer.js',
  'supabase-config.js'
];

fs.rmSync(output, { recursive: true, force: true });
fs.mkdirSync(output, { recursive: true });
fs.copyFileSync(path.join(root, 'imcc.html'), path.join(output, 'index.html'));

for (const file of staticFiles) {
  const source = path.join(root, file);
  if (!fs.existsSync(source)) {
    throw new Error(`Required static asset is missing: ${file}`);
  }
  fs.copyFileSync(source, path.join(output, file));
}
console.log('Static site built in ./public');
