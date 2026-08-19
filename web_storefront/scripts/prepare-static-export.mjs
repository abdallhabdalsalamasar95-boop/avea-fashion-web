import { cp, readdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

const outputDirectory = join(process.cwd(), "out");
const nextAssetsDirectory = join(outputDirectory, "_next");
const publicAssetsDirectory = join(outputDirectory, "assets");

await cp(nextAssetsDirectory, join(publicAssetsDirectory, "_next"), {
  recursive: true,
});

async function rewriteFiles(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      await rewriteFiles(path);
      continue;
    }

    if (!/\.(html|css|js|json|map)$/.test(entry.name)) continue;
    const content = await readFile(path, "utf8");
    if (content.includes("/_next/")) {
      await writeFile(path, content.replaceAll("/_next/", "/assets/_next/"));
    }
  }
}

await rewriteFiles(outputDirectory);