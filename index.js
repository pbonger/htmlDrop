#!/usr/bin/env node
const { execFileSync } = require('child_process');

const [,, file] = process.argv;
if (!file) { console.error('Usage: html-drop <file.html>'); process.exit(1); }

(async () => {
  const html = require('fs').readFileSync(file, 'utf8');

  const res = await fetch('https://pagedrop.io/api/upload', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ html, ttl: '3d' }),
  });

  if (!res.ok) throw new Error(`HTML Drop ${res.status}: ${await res.text()}`);

  const { url } = await res.json();

  execFileSync('pbcopy', [], { input: url });
  execFileSync('osascript', ['-e', `display notification "${url}" with title "HTML Drop"`]);

  console.log(url);
})().catch(e => { console.error(e.message); process.exit(1); });
