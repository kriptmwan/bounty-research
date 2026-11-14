// Tunnel debug: CONNECT to proxy, TLS to ws.derivws.com:443, then plain HTTPS GET /
// (a non-upgrade GET is expected to fail at the app layer; we only care that TLS works).
const net = require('net');
const tls = require('tls');
const proxy = new URL(process.env.HTTPS_PROXY || process.env.https_proxy);
console.error('proxy host:', proxy.hostname, 'port:', proxy.port);
const sock = net.connect(Number(proxy.port), proxy.hostname);
sock.setTimeout(10000);
sock.on('timeout', () => { console.error('TIMEOUT waiting'); sock.destroy(); process.exit(1); });
sock.on('error', (e) => { console.error('SOCKET ERROR:', e.message); process.exit(1); });
sock.on('connect', () => {
  console.error('TCP to proxy: connected');
  let req = 'CONNECT ws.derivws.com:443 HTTP/1.1\r\nHost: ws.derivws.com:443\r\n';
  if (proxy.username) {
    req += 'Proxy-Authorization: Basic ' + Buffer.from(
      decodeURIComponent(proxy.username) + ':' + decodeURIComponent(proxy.password)).toString('base64') + '\r\n';
  }
  req += 'Proxy-Connection: keep-alive\r\n\r\n';
  sock.write(req);
  console.error('CONNECT sent');
});
let buf = Buffer.alloc(0);
let tunneled = false;
sock.on('data', (chunk) => {
  if (tunneled) return;
  buf = Buffer.concat([buf, chunk]);
  const idx = buf.indexOf('\r\n\r\n');
  if (idx === -1) { console.error('partial proxy response, waiting...'); return; }
  console.error('proxy response head:', JSON.stringify(buf.slice(0, idx).toString()));
  const leftover = buf.slice(idx + 4);
  if (leftover.length) sock.unshift(leftover);
  tunneled = true;
  const ts = tls.connect({ socket: sock, servername: 'ws.derivws.com' });
  ts.on('error', (e) => { console.error('TLS ERROR:', e.message); process.exit(1); });
  ts.on('secureConnect', () => {
    console.error('TLS secureConnect, cipher:', ts.getCipher().name, 'peer cert CN:', ts.getPeerCertificate().subject);
    ts.write('GET / HTTP/1.1\r\nHost: ws.derivws.com\r\nConnection: close\r\n\r\n');
  });
  ts.on('data', (d) => { console.error('HTTPS response first bytes:', JSON.stringify(d.toString().slice(0, 200))); ts.destroy(); process.exit(0); });
});
