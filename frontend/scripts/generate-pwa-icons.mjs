import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { deflateSync } from "node:zlib";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");

const sizes = [192, 512];
const apps = [
  { dir: "farm-app/public", bg: "#0B5E2E", letter: "F", label: "Farm" },
  { dir: "admin-app/public", bg: "#1E3A5F", letter: "A", label: "Admin" },
];

function crc32(data) {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) {
      crc = crc & 1 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const typeBuf = Buffer.from(type);
  const crcInput = Buffer.concat([typeBuf, data]);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(crcInput));
  return Buffer.concat([length, typeBuf, data, crcBuf]);
}

function makeSolidPng(size, hex) {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;

  const rowSize = 1 + size * 3;
  const raw = Buffer.alloc(rowSize * size);
  for (let y = 0; y < size; y++) {
    const rowStart = y * rowSize;
    raw[rowStart] = 0;
    for (let x = 0; x < size; x++) {
      const px = rowStart + 1 + x * 3;
      raw[px] = r;
      raw[px + 1] = g;
      raw[px + 2] = b;
    }
  }

  return Buffer.concat([
    signature,
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", deflateSync(raw)),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
}

for (const app of apps) {
  const outDir = join(root, app.dir);
  mkdirSync(outDir, { recursive: true });
  for (const size of sizes) {
    writeFileSync(join(outDir, `icon-${size}.png`), makeSolidPng(size, app.bg));
  }
  writeFileSync(
    join(outDir, "icon.svg"),
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="${app.bg}"/><text x="256" y="300" font-size="220" fill="#fff" text-anchor="middle" font-family="system-ui,sans-serif" font-weight="700">${app.letter}</text></svg>`,
  );
  console.log(`Generated PWA icons for ${app.label} in ${app.dir}`);
}
