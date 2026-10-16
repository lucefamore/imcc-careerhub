// Copies the static site into ./public so only the site's own files are published
// (package.json, vercel.json, SQL, Dockerfile and build scripts are NOT served).
// The serverless function in ./api is deployed separately by Vercel.
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
fs.copyFileSync(path.join(root, 'imcc.html'), path.join(root, 'index.html')); // keep root copy in sync
fs.copyFileSync(path.join(root, 'imcc.html'), path.join(output, 'index.html'));

for (const file of staticFiles) {
    fs.copyFileSync(path.join(root, file), path.join(output, file));
}
console.log('Built ' + (staticFiles.length + 1) + ' files into public/');
