import { ethers } from '/home/hatch/workspace/nonce-mint/node_modules/ethers/lib.esm/index.js';
import fs from 'node:fs';

// Phase 0B enumeration: registry pairs + per-pair state. Read-only.
// Writes ~/workspace/frax-audit/pairs-enumeration-block<BLOCK>.json
const RPC = 'https://ethereum-rpc.publicnode.com';
const provider = new ethers.JsonRpcProvider(RPC);
const REG = '0xD6E9D27C75Afd88ad24Cd5EdccdC76fd2fc3A751';
const DEP_A = '0x5d6e79Bcf90140585CE88c7119b7E43CAaA67044';
const DEP_B = '0xF767A82a188305461b6f01a7706f7Bc0ba941ffF';

const regAbi = [
  'function deployedPairsLength() view returns (uint256)',
  'function getAllPairAddresses() view returns (address[])',
  'function owner() view returns (address)',
  'function deployers(address) view returns (bool)',
  'function pendingOwner() view returns (address)',
];
const depAbi = [
  'function getAllPairAddresses() view returns (address[])',
  'function deployedPairsLength() view returns (uint256)',
];
const pairAbi = [
  'function asset() view returns (address)',
  'function collateralContract() view returns (address)',
  'function totalAsset() view returns (uint128 amount, uint128 shares)',
  'function totalBorrow() view returns (uint128 amount, uint128 shares)',
  'function totalSupply() view returns (uint256)',
  'function totalCollateral() view returns (uint256)',
  'function paused() view returns (bool)',
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function oracleMultiply() view returns (address)',
  'function oracleDivide() view returns (address)',
  'function rateContract() view returns (address)',
  'function maxLTV() view returns (uint256)',
  'function version() view returns (uint256,uint256,uint256)',
  'function exchangeRateInfo() view returns (uint32,uint224)',
];
const erc20Abi = [
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function name() view returns (string)',
];

// Normalize ethers Results/bigints into plain JSON-safe values.
function norm(v) {
  if (typeof v === 'bigint') return v.toString();
  if (v !== null && typeof v === 'object' && typeof v.length === 'number') {
    return Array.from(v).map(norm);
  }
  if (v !== null && typeof v === 'object' && 'amount' in v && 'shares' in v) {
    return { amount: norm(v.amount), shares: norm(v.shares) };
  }
  return v;
}

const blockNumber = await provider.getBlockNumber();
console.log('block', blockNumber);
const reg = new ethers.Contract(REG, regAbi, provider);
const [len, pairs, owner] = await Promise.all([
  reg.deployedPairsLength(), reg.getAllPairAddresses(), reg.owner(),
]);
console.log('registry len', len.toString(), 'pairs returned', pairs.length, 'owner', owner);
let pendingOwner = null;
try { pendingOwner = await reg.pendingOwner(); } catch (e) { pendingOwner = 'REVERT: ' + String(e).slice(0, 120); }
console.log('pendingOwner', pendingOwner);
console.log('deployers[A]', await reg.deployers(DEP_A), 'deployers[B]', await reg.deployers(DEP_B));

const depA = new ethers.Contract(DEP_A, depAbi, provider);
const depB = new ethers.Contract(DEP_B, depAbi, provider);
const [pairsA, pairsB] = await Promise.all([depA.getAllPairAddresses(), depB.getAllPairAddresses()]);
console.log('deployerA pairs', pairsA.length, 'deployerB pairs', pairsB.length);

const results = [];
for (let i = 0; i < pairs.length; i += 8) {
  const chunk = pairs.slice(i, i + 8);
  const chunkRes = await Promise.all(chunk.map(async (addr) => {
    const c = new ethers.Contract(addr, pairAbi, provider);
    const out = { pair: addr };
    const calls = {
      asset: () => c.asset(), collateral: () => c.collateralContract(),
      totalAsset: () => c.totalAsset(), totalBorrow: () => c.totalBorrow(),
      totalSupply: () => c.totalSupply(), totalCollateral: () => c.totalCollateral(),
      paused: () => c.paused(), name: () => c.name(), symbol: () => c.symbol(),
      decimals: () => c.decimals(), oracleMultiply: () => c.oracleMultiply(),
      oracleDivide: () => c.oracleDivide(), rateContract: () => c.rateContract(),
      maxLTV: () => c.maxLTV(), version: () => c.version(),
      exchangeRateInfo: () => c.exchangeRateInfo(),
    };
    for (const [k, fn] of Object.entries(calls)) {
      try { out[k] = norm(await fn()); } catch (e) { out[k] = 'ERR:' + String(e).slice(0, 100); }
    }
    return out;
  }));
  results.push(...chunkRes);
  console.log('chunk done', i + chunk.length, '/', pairs.length);
}

const tokens = [...new Set(results.flatMap(r => [r.asset, r.collateral]).filter(Boolean))];
const tokMeta = {};
for (let i = 0; i < tokens.length; i += 8) {
  const chunk = tokens.slice(i, i + 8);
  await Promise.all(chunk.map(async (t) => {
    const c = new ethers.Contract(t, erc20Abi, provider);
    const m = {};
    for (const [k, fn] of Object.entries({ decimals: () => c.decimals(), symbol: () => c.symbol(), name: () => c.name() })) {
      try { m[k] = norm(await fn()); } catch (e) { m[k] = 'ERR'; }
    }
    tokMeta[t] = m;
  }));
}

const outPath = `/home/hatch/workspace/frax-audit/pairs-enumeration-block${blockNumber}.json`;
fs.writeFileSync(outPath, JSON.stringify({
  blockNumber, registry: REG, registryLength: len.toString(), owner, pendingOwner,
  deployerA_pairs: Array.from(pairsA), deployerB_pairs: Array.from(pairsB),
  pairs: results, tokens: tokMeta,
}, null, 2));
console.log('WROTE', outPath);
