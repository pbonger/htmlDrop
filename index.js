#!/usr/bin/env node
const { execFileSync } = require('child_process');

const [,, file] = process.argv;
if (!file) { console.error('Usage: htmlshare <file.html>'); process.exit(1); }

(async () => {
  const zip = execFileSync('zip', ['-j', '-', file]);

  const res = await fetch('https://api.netlify.com/api/v1/sites', {
    method: 'POST',
    headers: { 'Content-Type': 'application/zip' },
    body: zip,
  });

  if (!res.ok) throw new Error(`Netlify ${res.status}: ${await res.text()}`);

  const { url } = await res.json();

  execFileSync('pbcopy', [], { input: url });
  execFileSync('osascript', ['-e', `display notification "${url}" with title "Netlify Share"`]);

  console.log(url);
})().catch(e => { console.error(e.message); process.exit(1); });
