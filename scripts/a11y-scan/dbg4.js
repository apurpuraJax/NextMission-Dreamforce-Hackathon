const { chromium } = require('playwright');
const fs = require('fs');
const URL = 'https://orgfarm-3bfff135af.my.site.com/nextmission/';
const B64 = fs.readFileSync('/tmp/pdf_b64.txt','utf8').trim();
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  await p.goto(URL,{waitUntil:'domcontentloaded',timeout:90000});
  await p.waitForTimeout(12000);
  const r = await p.evaluate(async (b64) => {
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let k=0;k<bin.length;k++) bytes[k]=bin.charCodeAt(k);
    const latin = new TextDecoder('latin1');
    const raw = latin.decode(bytes);
    const log = { bytes: bytes.length, rawLen: raw.length, streams: [] };
    let i=0;
    while (log.streams.length < 10) {
      const s = raw.indexOf('stream', i);
      if (s===-1) break;
      const dict = raw.slice(Math.max(0, raw.lastIndexOf('<<', s)), s);
      let from = s+6;
      if (raw[from]==='\r') from++;
      if (raw[from]==='\n') from++;
      const e = raw.indexOf('endstream', from);
      if (e===-1) break;
      i = e+9;
      const rec = { at:s, dictHasFlate: /\/FlateDecode/.test(dict), len: e-from,
                    dictSnip: dict.slice(-70).replace(/\s+/g,' ') };
      const slice = bytes.subarray(from, e);
      try {
        const ds = new DecompressionStream('deflate');
        const inf = new Uint8Array(await new Response(new Blob([slice]).stream().pipeThrough(ds)).arrayBuffer());
        rec.inflated = inf.length;
        rec.sample = latin.decode(inf).slice(0,90);
      } catch (err) { rec.inflateErr = String(err).slice(0,90); }
      log.streams.push(rec);
    }
    return log;
  }, B64);
  console.log(JSON.stringify(r, null, 2).slice(0, 2600));
  await b.close();
})();
