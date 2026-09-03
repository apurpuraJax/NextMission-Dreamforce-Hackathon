const { chromium } = require('playwright');
const URL = 'https://orgfarm-3bfff135af.my.site.com/nextmission/';
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  await p.goto(URL,{waitUntil:'domcontentloaded',timeout:90000});
  await p.waitForTimeout(12000);
  const r = await p.evaluate(async () => {
    const res = { hasDS: typeof DecompressionStream !== 'undefined',
                  hasBlobStream: typeof Blob !== 'undefined' && !!Blob.prototype.stream,
                  hasResponse: typeof Response !== 'undefined' };
    if (res.hasDS) {
      try {
        // zlib-wrap "hello" and round-trip it
        const cs = new CompressionStream('deflate');
        const packed = new Uint8Array(await new Response(
          new Blob([new TextEncoder().encode('hello')]).stream().pipeThrough(cs)).arrayBuffer());
        const ds = new DecompressionStream('deflate');
        const back = await new Response(
          new Blob([packed]).stream().pipeThrough(ds)).text();
        res.roundTrip = back;
      } catch (e) { res.roundTripError = String(e).slice(0,160); }
    }
    return res;
  });
  console.log(JSON.stringify(r, null, 2));
  await b.close();
})();
