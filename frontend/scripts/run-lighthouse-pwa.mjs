import * as chromeLauncher from "chrome-launcher";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const lighthouse = require("lighthouse");

const targets = [
  { label: "Farm App", url: "http://127.0.0.1:4173" },
  { label: "Admin App", url: "http://127.0.0.1:4174" },
];

const PWA_AUDITS = [
  "installable-manifest",
  "service-worker",
  "works-offline",
  "themed-omnibox",
  "maskable-icon",
  "content-width",
  "viewport",
  "splash-screen",
];

async function auditTarget({ label, url }) {
  const chrome = await chromeLauncher.launch({
    chromeFlags: ["--headless=new", "--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"],
  });

  try {
    const runnerResult = await lighthouse(
      url,
      { port: chrome.port, output: "json", logLevel: "error", onlyCategories: ["pwa"] },
      undefined,
    );

    const report = runnerResult?.lhr;
    if (!report) throw new Error("No Lighthouse report returned");

    const score = Math.round((report.categories.pwa?.score ?? 0) * 100);
    console.log(`=== ${label} (${url}) ===`);
    console.log(`PWA score: ${score}/100`);
    for (const id of PWA_AUDITS) {
      const audit = report.audits[id];
      if (!audit) continue;
      const status =
        audit.score === 1 ? "PASS" : audit.score === 0 ? "FAIL" : "N/A";
      console.log(`${id}: ${status}`);
    }
    console.log("");
  } finally {
    await chrome.kill();
  }
}

for (const target of targets) {
  await auditTarget(target);
}
