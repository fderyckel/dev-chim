// @vitest-environment node
import { afterEach, describe, expect, it } from "vitest";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

import manifest from "../../../../demo-data/manifest.json";
import { intervalState, projectDemo, type DemoPack } from "../../src/lib/demo-instance";
import { loadDemoInstance, loopbackHost } from "../../src/server/demo-instance-loader";

const root = path.resolve("../..");
const directories: string[] = [];
afterEach(async () => {
  await Promise.all(
    directories.splice(0).map((d) => rm(d, { recursive: true, force: true })),
  );
});

async function prepared(slug: string) {
  const directory = await mkdtemp(path.join(tmpdir(), "chim-demo-loader-"));
  directories.push(directory);
  await mkdir(path.join(directory, "packs"));
  for (const entry of manifest.packs) {
    await writeFile(
      path.join(directory, entry.path),
      await readFile(path.join(root, "demo-data", entry.path)),
    );
  }
  const content = await readFile(
    path.join(root, "demo-data/packs", `${slug}.json`),
    "utf8",
  );
  const pack = JSON.parse(content) as DemoPack;
  await writeFile(path.join(directory, "packs", `${slug}.json`), content);
  const context = {
    environment: "local-synthetic",
    synthetic: true,
    catalog_version: 1,
    pack_ids: manifest.packs.map((entry) => entry.pack_id),
    selected_pack_id: slug,
    selected_tenant_id: pack.tenant_id,
  };
  await writeFile(path.join(directory, "instance.json"), JSON.stringify(context));
  const env = {
    NODE_ENV: "test",
    CHIMWEMWE_DEMO_INSTANCE: "true",
    CHIMWEMWE_UI0_SYNTHETIC: "true",
    CHIMWEMWE_DEMO_DATA_DIRECTORY: directory,
    CHIMWEMWE_DEMO_PACK_ID: slug,
  } satisfies NodeJS.ProcessEnv;
  return { directory, content, pack, context, env };
}

describe("selected local demo context", () => {
  for (const entry of manifest.packs)
    it(`loads ${entry.pack_id} with its actual joins`, async () => {
      const { env, pack } = await prepared(entry.pack_id);
      const data = await loadDemoInstance("127.0.0.1:3000", env);
      expect(data.students).toHaveLength(entry.counts.students);
      expect(data.educators).toHaveLength(entry.counts.educators);
      expect(data.contacts.length).toBeGreaterThan(0);
      expect(data.currentEnrolments).toBe(data.students.length - 2);
      const applicantIds = new Set(pack.records.applications.map((r) => r.person_id));
      expect(pack.records.students.some((r) => applicantIds.has(r.person_id))).toBe(
        false,
      );
      expect(data.students[0].name).toBe(data.students[1].name);
      expect(data.students[0].reference).not.toBe(data.students[1].reference);
      expect(
        data.students
          .find((s) => s.enrolment.state === "Starts later")
          ?.registers.every((r) => r.state !== "Current"),
      ).toBe(true);
    });

  it("uses half-open boundaries for each dated record", () => {
    expect(intervalState("2026-10-12", "2026-11-01", "2026-10-11")).toBe(
      "Starts later",
    );
    expect(intervalState("2026-10-12", "2026-11-01", "2026-10-12")).toBe("Current");
    expect(intervalState("2026-10-12", "2026-11-01", "2026-11-01")).toBe("Ended");
  });

  it("switches all four packs in one prepared instance without changing the startup default", async () => {
    const { env, directory, context } = await prepared("bangkok-international");
    const institutionIds = new Set<string>();
    for (const entry of manifest.packs) {
      const data = await loadDemoInstance("127.0.0.1:3000", env, entry.pack_id);
      expect(data.packId).toBe(entry.pack_id);
      expect(data.students).toHaveLength(entry.counts.students);
      expect(data.educators).toHaveLength(entry.counts.educators);
      institutionIds.add(data.institutionId);
    }
    expect(institutionIds.size).toBe(4);
    expect(
      JSON.parse(await readFile(path.join(directory, "instance.json"), "utf8")),
    ).toEqual(context);
    expect((await loadDemoInstance("127.0.0.1", env)).packId).toBe(
      "bangkok-international",
    );
  });

  it("refuses invalid, repeated, path-shaped or unprepared choices and still validates startup context", async () => {
    const { env, directory, context } = await prepared("bangkok-international");
    for (const selection of [
      "",
      "unknown",
      "../england-independent",
      context.selected_tenant_id,
      ["england-independent"],
      ["england-independent", "us-community-college"],
    ]) {
      await expect(loadDemoInstance("127.0.0.1", env, selection)).rejects.toThrow(
        "institution",
      );
    }
    await expect(
      loadDemoInstance("school.example", env, "england-independent"),
    ).rejects.toThrow("disabled");
    await expect(
      loadDemoInstance(
        "127.0.0.1",
        { ...env, CHIMWEMWE_DEMO_INSTANCE: "false" },
        "england-independent",
      ),
    ).rejects.toThrow("disabled");
    await writeFile(
      path.join(directory, "instance.json"),
      JSON.stringify({ ...context, pack_ids: ["bangkok-international"] }),
    );
    await expect(
      loadDemoInstance("127.0.0.1", env, "england-independent"),
    ).rejects.toThrow("institution");
    await writeFile(
      path.join(directory, "instance.json"),
      JSON.stringify({ ...context, selected_tenant_id: "wrong" }),
    );
    await expect(
      loadDemoInstance("127.0.0.1", env, "england-independent"),
    ).rejects.toThrow("tenant");
    await writeFile(path.join(directory, "instance.json"), JSON.stringify(context));
    await writeFile(path.join(directory, "packs/england-independent.json"), "{}");
    await expect(
      loadDemoInstance("127.0.0.1", env, "england-independent"),
    ).rejects.toThrow("digest");
    await rm(path.join(directory, "packs/hong-kong-kindergarten.json"));
    await expect(
      loadDemoInstance("127.0.0.1", env, "hong-kong-kindergarten"),
    ).rejects.toThrow();
  });

  it("keeps college contacts and sections distinct and applicant-only people out", async () => {
    const { pack } = await prepared("us-community-college");
    const data = projectDemo(pack);
    expect(data.college).toBe(true);
    expect(data.students.every((s) => s.registers.length === 0)).toBe(true);
    expect(data.students.some((s) => s.sections.length > 1)).toBe(true);
    expect(data.students.some((s) => s.contacts.length === 0)).toBe(true);
    expect(data.contacts[0].learners[0].purpose).toContain("emergency contact example");
  });

  it("deduplicates contacts by ID and preserves shared-email people and ended links", async () => {
    const { pack } = await prepared("england-independent");
    const data = projectDemo(pack);
    const shared = data.contacts.filter(
      (c) => c.email === "shared-family@example.test",
    );
    expect(shared).toHaveLength(2);
    expect(shared[0].id).not.toBe(shared[1].id);
    expect(data.contacts.some((c) => c.learners.some((l) => l.state === "Ended"))).toBe(
      true,
    );
    expect(data.contacts.some((c) => c.email === null)).toBe(true);
  });

  it("fails closed on missing flags, remote Host, corrupt pack, and mismatched tenant or selection", async () => {
    const { env, directory, context } = await prepared("bangkok-international");
    await expect(loadDemoInstance("127.0.0.1", { NODE_ENV: "test" })).rejects.toThrow();
    await expect(loadDemoInstance("school.example", env)).rejects.toThrow();
    await expect(
      loadDemoInstance("127.0.0.1", { ...env, CHIMWEMWE_UI0_SYNTHETIC: "false" }),
    ).rejects.toThrow();
    await expect(
      loadDemoInstance("127.0.0.1", {
        ...env,
        CHIMWEMWE_DEMO_PACK_ID: "england-independent",
      }),
    ).rejects.toThrow();
    await writeFile(
      path.join(directory, "instance.json"),
      JSON.stringify({ ...context, selected_tenant_id: "another-tenant" }),
    );
    await expect(loadDemoInstance("127.0.0.1", env)).rejects.toThrow("tenant");
    await writeFile(path.join(directory, "instance.json"), JSON.stringify(context));
    await writeFile(path.join(directory, "packs/bangkok-international.json"), "{}");
    await expect(loadDemoInstance("127.0.0.1", env)).rejects.toThrow("digest");
  });

  it("accepts only exact loopback host syntax", () => {
    for (const host of ["localhost:3000", "127.0.0.1:3025", "[::1]:3000"])
      expect(loopbackHost(host)).toBe(true);
    for (const host of [
      null,
      "localhost.evil",
      "127.0.0.1@evil.test",
      "localhost/path",
      "localhost:3000@evil.test",
    ])
      expect(loopbackHost(host)).toBe(false);
  });
});
