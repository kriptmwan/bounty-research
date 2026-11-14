// WHATWG URL behaviour (same parser browsers use for Location/location.assign)
// + verbatim copies of reporter.js:7 and desk.js:140 safe().
const base = "https://bounty.xe.network/signin";
const nxt = "/\t/evil.com/phish"; // literal TAB, as decoded from %09

const reporterSafe = (n) => (n && n.startsWith("/") && !n.startsWith("//") && !n.includes("\\")) ? n : "/my";
const deskSafe = (n) => (n && n.startsWith("/") && !n.startsWith("//") && !n.startsWith("/\\")) ? n : "/";

console.log("reporter safe():", JSON.stringify(reporterSafe(nxt)));
console.log("desk safe():    ", JSON.stringify(deskSafe(nxt)));
console.log("new URL(nxt, base).href =", new URL(nxt, base).href);
console.log("new URL('/\\t/evil.com', base) via Location semantics =", new URL("/\t/evil.com/", base).href);
console.log("control /my ->", new URL("/my", base).href);
