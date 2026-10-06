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

fs.mkdirSync(output, { recursive: true });
fs.copyFileSync(path.join(root, 'imcc.html'), path.join(output, 'index.html'));

for (const file of staticFiles) {
    fs.copyFileSync(path.join(root, file), path.join(output, file));
}
