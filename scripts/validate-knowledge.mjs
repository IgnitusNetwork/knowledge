#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const repoRoot = process.cwd();
const knowledgeRoot = path.join(repoRoot, "knowledge");
const encyclopediaRoot = path.join(knowledgeRoot, "encyclopedia");

function listFilesRecursive(dir) {
  /** @type {string[]} */
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...listFilesRecursive(p));
    else out.push(p);
  }
  return out;
}

function rel(p) {
  return path.relative(repoRoot, p).replaceAll("\\", "/");
}

function readText(p) {
  return fs.readFileSync(p, "utf8");
}

function loadDenylist() {
  const denyPath = path.join(knowledgeRoot, "scripts", "denylist.txt");
  if (!fs.existsSync(denyPath)) return [];
  return readText(denyPath)
    .split(/\r?\n/g)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#"));
}

const REQUIRED_HEADINGS = [
  "## What it is",
  "## What happens to your money (user POV)",
  "## Common ways users get hurt",
  "## Simple example with numbers",
  "## What to check (safety checklist)",
  "## Further reading (internal only)",
];

function validateEncyclopediaMarkdown(filePath, denylist) {
  const text = readText(filePath);

  /** @type {string[]} */
  const errors = [];

  for (const h of REQUIRED_HEADINGS) {
    if (!text.includes(h)) errors.push(`Missing required heading: ${h}`);
  }

  if (!text.includes("This is not financial advice.")) {
    errors.push("Missing safety footer line: 'This is not financial advice.'");
  }

  for (const term of denylist) {
    const re = new RegExp(`\\b${term.replace(/[.*+?^${}()|[\\]\\\\]/g, "\\$&")}\\b`, "i");
    if (re.test(text)) errors.push(`Forbidden name found (denylist): ${term}`);
  }

  return errors;
}

function main() {
  if (!fs.existsSync(knowledgeRoot)) {
    console.error("Missing knowledge/ directory.");
    process.exit(1);
  }
  if (!fs.existsSync(encyclopediaRoot)) {
    console.error("Missing knowledge/encyclopedia/ directory.");
    process.exit(1);
  }

  const denylist = loadDenylist();
  const encyclopediaFiles = listFilesRecursive(encyclopediaRoot).filter((p) => p.endsWith(".md"));

  /** @type {{file: string, errors: string[]}[]} */
  const failures = [];

  for (const f of encyclopediaFiles) {
    // Templates are allowed to be incomplete.
    if (path.basename(f).startsWith("_template")) continue;
    const errs = validateEncyclopediaMarkdown(f, denylist);
    if (errs.length) failures.push({ file: rel(f), errors: errs });
  }

  if (failures.length) {
    console.error(`Knowledge validation failed (${failures.length} file(s)).`);
    for (const { file, errors } of failures) {
      console.error(`- ${file}`);
      for (const e of errors) console.error(`  - ${e}`);
    }
    process.exit(1);
  }

  console.log(`Knowledge validation passed (${encyclopediaFiles.length} markdown file(s) checked).`);
}

main();

