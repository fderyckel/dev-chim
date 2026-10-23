import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";

import { projectDemo, type DemoPack } from "../lib/demo-instance";
import type { DemoInstance } from "../ports/demo-instance";
import { isDemoInstitution } from "../lib/demo-institutions";

type DemoEnvironment = Readonly<Record<string, string | undefined>>;
type DemoManifest = Readonly<{
  packs: readonly Readonly<{ pack_id: string; path: string; sha256: string }>[];
}>;

export function loopbackHost(host: string | null) {
  if (!host) return false;
  try {
    const url = new URL(`http://${host}`);
    return (
      !url.username &&
      !url.password &&
      url.host === host &&
      ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)
    );
  } catch {
    return false;
  }
}

export async function loadDemoInstance(
  host: string | null,
  env: DemoEnvironment = process.env,
  selection?: unknown,
): Promise<DemoInstance> {
  if (
    env.CHIMWEMWE_DEMO_INSTANCE !== "true" ||
    env.CHIMWEMWE_UI0_SYNTHETIC !== "true" ||
    !loopbackHost(host) ||
    !env.CHIMWEMWE_DEMO_DATA_DIRECTORY
  ) {
    throw new Error("Demo disabled");
  }
  const directory = env.CHIMWEMWE_DEMO_DATA_DIRECTORY;
  const manifest = JSON.parse(
    await readFile(
      path.resolve(process.cwd(), "../../demo-data/manifest.json"),
      "utf8",
    ),
  ) as DemoManifest;
  const instance = JSON.parse(
    await readFile(path.join(directory, "instance.json"), "utf8"),
  );
  if (
    instance.environment !== "local-synthetic" ||
    instance.synthetic !== true ||
    instance.catalog_version !== 1
  )
    throw new Error("Invalid demo instance");
  const startupEntry = manifest.packs.find(
    (p) => p.pack_id === instance.selected_pack_id,
  );
  if (
    !startupEntry ||
    !isDemoInstitution(startupEntry.pack_id) ||
    env.CHIMWEMWE_DEMO_PACK_ID !== startupEntry.pack_id
  )
    throw new Error("Unknown demo institution");
  const startupPack = await readPack(directory, startupEntry);
  if (startupPack.tenant_id !== instance.selected_tenant_id)
    throw new Error("Invalid demo tenant context");
  const selectedId = selection === undefined ? startupEntry.pack_id : selection;
  if (
    !isDemoInstitution(selectedId) ||
    !Array.isArray(instance.pack_ids) ||
    !instance.pack_ids.includes(selectedId)
  )
    throw new Error("Unknown demo institution");
  const entry = manifest.packs.find((p) => p.pack_id === selectedId);
  if (!entry) throw new Error("Unknown demo institution");
  const pack =
    entry.pack_id === startupEntry.pack_id
      ? startupPack
      : await readPack(directory, entry);
  return projectDemo(pack);
}

async function readPack(directory: string, entry: DemoManifest["packs"][number]) {
  const content = await readFile(path.join(directory, entry.path), "utf8");
  if (createHash("sha256").update(content).digest("hex") !== entry.sha256)
    throw new Error("Invalid demo digest");
  const pack = JSON.parse(content) as DemoPack;
  if (
    pack.pack_id !== entry.pack_id ||
    pack.schema_version !== 1 ||
    pack.synthetic !== true ||
    pack.usage !== "local_synthetic_scenarios_only" ||
    typeof pack.tenant_id !== "string" ||
    !pack.tenant_id ||
    pack.accounts.length ||
    pack.authorization_grants.length ||
    Object.values(pack.records).some((rows) =>
      rows.some((row) => row.tenant_id !== pack.tenant_id),
    )
  ) {
    throw new Error("Invalid demo tenant context");
  }
  return pack;
}
