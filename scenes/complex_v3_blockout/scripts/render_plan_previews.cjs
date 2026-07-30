#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");
const { chromium } = require("C:/Users/rosi0/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright");

const repo = path.resolve(__dirname, "../../..");
const output = process.argv[2] || path.join(process.env.TEMP, "caretaker-complex-v3-visual-audit", "plans");
const planDir = path.join(repo, "docs", "design", "complex_v3");
const catalog = JSON.parse(fs.readFileSync(path.join(repo, "scenes", "complex_v3_blockout", "sector_catalog.json"), "utf8"));

async function main() {
  fs.mkdirSync(output, { recursive: true });
  let browser;
  try {
    browser = await chromium.launch({ channel: "msedge", headless: true });
  } catch (_error) {
    browser = await chromium.launch({ headless: true });
  }
  const page = await browser.newPage({ viewport: { width: 1500, height: 1500 }, deviceScaleFactor: 1 });
  for (const sector of catalog.sectors) {
    const slug = sector.sector_id.toLowerCase().replaceAll("-", "_");
    const source = path.join(planDir, `${slug}.html`);
    await page.goto(pathToFileURL(source).href, { waitUntil: "domcontentloaded" });
    const frame = page.frames().find((candidate) => candidate !== page.mainFrame()) || page.mainFrame();
    const svg = frame.locator("svg").first();
    const image = frame.locator("img").first();
    if (await svg.count()) {
      await svg.waitFor({ state: "visible" });
      await svg.screenshot({ path: path.join(output, `${slug}.png`) });
    } else if (await image.count()) {
      await image.waitFor({ state: "visible" });
      await image.screenshot({ path: path.join(output, `${slug}.png`) });
    } else {
      await page.screenshot({ path: path.join(output, `${slug}.png`), fullPage: true });
    }
    process.stdout.write(`PLAN_PREVIEW ${sector.sector_id}\n`);
  }
  await browser.close();
  process.stdout.write(`PLAN_PREVIEWS_OK count=${catalog.sectors.length} output=${output}\n`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
