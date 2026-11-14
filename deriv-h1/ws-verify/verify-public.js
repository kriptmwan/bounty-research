// Deriv WS public-call verification — READ ONLY. No auth, no token, no trades.
// Single host: wss://ws.derivws.com/websockets/v3?app_id=1089
// Header X-HackerOne-Research: mosul on the upgrade request.
const WebSocket = require('ws');
const fs = require('fs');
const net = require('net');
const tls = require('tls');
const { Agent } = require('https');

// VM egress goes through an HTTP proxy (env vars); ws does not honor proxy
// env vars, so tunnel via HTTP CONNECT using Node built-ins only. The proxy
// URL/credentials are read in-process from the environment and never logged.
class ConnectAgent extends Agent {
  createConnection(options, cb) {
    console.error('[agent] createConnection host=' + options.host + ' port=' + options.port);
    const proxy = new URL(process.env.HTTPS_PROXY || process.env.https_proxy);
    const targetHost = options.host;
    const targetPort = options.port || 443;
    const sock = net.connect(Number(proxy.port), proxy.hostname);
    let settled = false;
    const fail = (e) => { if (!settled) { settled = true; try { sock.destroy(); } catch {} cb(e); } };
    sock.once('error', fail);
    sock.once('connect', () => {
      console.error('[agent] TCP to proxy connected, sending CONNECT');
      let req = `CONNECT ${targetHost}:${targetPort} HTTP/1.1\r\nHost: ${targetHost}:${targetPort}\r\n`;
      if (proxy.username) {
        req += 'Proxy-Authorization: Basic ' + Buffer.from(
          decodeURIComponent(proxy.username) + ':' + decodeURIComponent(proxy.password)).toString('base64') + '\r\n';
      }
      req += 'Proxy-Connection: keep-alive\r\n\r\n';
      sock.write(req);
    });
    let buf = Buffer.alloc(0);
    const onData = (chunk) => {
      buf = Buffer.concat([buf, chunk]);
      const idx = buf.indexOf('\r\n\r\n');
      if (idx === -1) return;
      const head = buf.slice(0, idx).toString();
      const status = parseInt(head.split(' ')[1], 10);
      console.error('[agent] CONNECT status ' + status);
      if (status !== 200) return fail(new Error('proxy CONNECT status ' + status));
      sock.removeListener('data', onData);
      sock.removeListener('error', fail);
      const leftover = buf.slice(idx + 4);
      if (leftover.length) sock.unshift(leftover);
      const tlsSock = tls.connect({ socket: sock, servername: options.servername || targetHost, ALPNProtocols: options.ALPNProtocols });
      tlsSock.once('error', fail);
      tlsSock.once('secureConnect', () => { console.error('[agent] TLS secureConnect, calling cb'); if (!settled) { settled = true; cb(null, tlsSock); } });
    };
    sock.on('data', onData);
  }
}

const WS_URL = 'wss://ws.derivws.com/websockets/v3?app_id=1089';
const LOG = __dirname + '/raw-2026-11-14.jsonl';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (dir, obj) => {
  fs.appendFileSync(LOG, JSON.stringify({ t: new Date().toISOString(), dir, ...obj }) + '\n');
};

const ws = new WebSocket(WS_URL, { headers: { 'X-HackerOne-Research': 'mosul' }, agent: new ConnectAgent() });
let reqId = 0;
const pending = new Map(); // req_id -> resolve
const streamMsgs = []; // tick stream messages (req_id absent or echo_req ticks)

ws.on('message', (data) => {
  let msg;
  try { msg = JSON.parse(data.toString()); } catch { return; }
  log('recv', { msg });
  if (msg.req_id !== undefined && pending.has(msg.req_id)) {
    pending.get(msg.req_id)(msg);
    pending.delete(msg.req_id);
  } else if (msg.msg_type === 'tick') {
    streamMsgs.push(msg);
  }
});
ws.on('error', (e) => { console.error('[ws] error:', String(e)); log('error', { message: String(e) }); });
ws.on('upgrade', (res) => { console.error('[ws] upgrade response status:', res.statusCode); });

function call(payload, timeoutMs = 15000) {
  const id = ++reqId;
  const req = { ...payload, req_id: id };
  return new Promise((resolve, reject) => {
    const to = setTimeout(() => { pending.delete(id); reject(new Error('timeout req_id ' + id)); }, timeoutMs);
    pending.set(id, (msg) => { clearTimeout(to); resolve(msg); });
    log('send', { req });
    ws.send(JSON.stringify(req));
  });
}

async function main() {
  fs.writeFileSync(LOG, '');
  await new Promise((resolve, reject) => {
    const to = setTimeout(() => reject(new Error('connect timeout')), 30000);
    ws.once('open', () => { clearTimeout(to); log('open', { url: WS_URL, header: 'X-HackerOne-Research: mosul' }); resolve(); });
    ws.once('error', (e) => { clearTimeout(to); reject(e); });
  });

  const results = {};

  results.ping = await call({ ping: 1 });
  await sleep(3000);

  results.active_symbols = await call({ active_symbols: 'brief' });
  await sleep(3000);

  // ticks: subscribe, take initial + 1 streamed update, then forget
  const tickResp = await call({ ticks: 'R_100', subscribe: 1 });
  results.ticks_initial = tickResp;
  const subId = tickResp.subscription && tickResp.subscription.id;
  await sleep(4000); // allow 1-2 streamed ticks to arrive
  results.ticks_streamed = streamMsgs.slice(0, 2);
  if (subId) {
    results.forget = await call({ forget: subId });
  } else {
    results.forget = { skipped: 'no subscription id in ticks response' };
  }
  await sleep(3000);

  results.proposal = await call({
    proposal: 1,
    contract_type: 'CALL',
    currency: 'USD',
    duration: 5,
    duration_unit: 't',
    amount: 10,
    basis: 'stake',
    underlying_symbol: 'R_100',
  });
  await sleep(3000);

  // NOTE: schema defines trading_times as a DATE string ('today' or yyyy-mm-dd), not a symbol.
  results.trading_times = await call({ trading_times: 'today' });

  // Print compact summaries to stdout for the operator
  const summarize = (name, m) => {
    if (!m || m.error) { console.log(name, 'ERROR:', JSON.stringify(m && m.error)); return; }
    console.log(name, 'msg_type=' + m.msg_type, 'top_keys=' + Object.keys(m).sort().join(','));
  };
  summarize('ping', results.ping);
  console.log('  ping value:', JSON.stringify(results.ping.ping));
  summarize('active_symbols', results.active_symbols);
  if (results.active_symbols.active_symbols) {
    console.log('  count:', results.active_symbols.active_symbols.length);
    const r100 = results.active_symbols.active_symbols.find((s) => s.underlying_symbol === 'R_100');
    console.log('  R_100 entry keys:', r100 ? Object.keys(r100).sort().join(',') : 'NOT FOUND');
    console.log('  R_100 entry:', JSON.stringify(r100));
  }
  summarize('ticks_initial', results.ticks_initial);
  console.log('  tick keys:', results.ticks_initial.tick ? Object.keys(results.ticks_initial.tick).sort().join(',') : 'none');
  console.log('  tick:', JSON.stringify(results.ticks_initial.tick));
  console.log('  subscription:', JSON.stringify(results.ticks_initial.subscription));
  console.log('  streamed tick msgs received:', streamMsgs.length);
  if (results.ticks_streamed[0]) console.log('  streamed[0] keys:', Object.keys(results.ticks_streamed[0]).sort().join(','), JSON.stringify(results.ticks_streamed[0].tick));
  summarize('forget', results.forget);
  console.log('  forget value:', JSON.stringify(results.forget.forget));
  summarize('proposal', results.proposal);
  if (results.proposal.proposal) {
    console.log('  proposal keys:', Object.keys(results.proposal.proposal).sort().join(','));
    const p = results.proposal.proposal;
    console.log('  proposal id/ask/payout/spot:', p.id, p.ask_price, p.payout, p.spot, '| longcode:', p.longcode);
  }
  summarize('trading_times', results.trading_times);
  if (results.trading_times.trading_times) {
    console.log('  trading_times keys:', Object.keys(results.trading_times.trading_times).sort().join(','));
    const mk = results.trading_times.trading_times.markets || [];
    console.log('  markets count:', mk.length, 'first market keys:', mk[0] ? Object.keys(mk[0]).sort().join(',') : 'none');
  }

  ws.close();
  await sleep(500);
  console.log('DONE — raw log:', LOG);
}

main().catch((e) => { console.error('FATAL:', e.message); log('fatal', { message: e.message }); try { ws.close(); } catch {} process.exit(1); });
