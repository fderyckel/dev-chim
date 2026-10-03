import assert from "node:assert/strict";
import test from "node:test";

import { compileDesignTokenDocuments } from "../../scripts/generate-design-tokens.mjs";

const schema = "https://www.designtokens.org/schemas/2025.10/format.json";

function color(hex, components) {
  return {
    colorSpace: "srgb",
    components,
    alpha: 1,
    hex,
  };
}

function referenceDocument(overrides = {}) {
  return {
    $schema: schema,
    palette: {
      $type: "color",
      ink: {
        $value: color("#112233", [17 / 255, 34 / 255, 51 / 255]),
      },
      paper: {
        $value: color("#ffffff", [1, 1, 1]),
      },
    },
    ...overrides,
  };
}

function semanticDocument(entries = {}) {
  return {
    $schema: schema,
    color: {
      $type: "color",
      surface: {
        $value: "{palette.paper}",
      },
      text: {
        $value: "{palette.ink}",
      },
      ...entries,
    },
  };
}

function profilesDocument(profiles = ["light"]) {
  return {
    schemaVersion: 1,
    defaultProfile: "light",
    profiles: profiles.map((id) => ({
      id,
      label: `Profile ${id}`,
      description: `Description for ${id}`,
      colorScheme: id === "dark" ? "dark" : "light",
      tokens: `${id}.tokens.json`,
    })),
  };
}

test("compiles stable generated CSS and typed profile metadata", async () => {
  const input = {
    referenceDocument: referenceDocument(),
    profilesDocument: profilesDocument(),
    profileDocuments: new Map([["light", semanticDocument()]]),
  };

  const first = await compileDesignTokenDocuments(input);
  const second = await compileDesignTokenDocuments(input);

  assert.equal(first.revision, second.revision);
  assert.equal(first.referenceTokenCount, 2);
  assert.equal(first.semanticTokenCount, 2);
  assert.match(first.artifacts.get("tokens.css"), /--palette-ink: #123;/);
  assert.match(
    first.artifacts.get("themes.css"),
    /--color-text: var\(--palette-ink\);/,
  );
  assert.match(first.artifacts.get("themes.css"), /:root\[data-theme="light"\]/);
  assert.match(
    first.artifacts.get("profiles.ts"),
    /defaultExperienceProfileId = "light"/,
  );
  assert.match(first.artifacts.get("profiles.ts"), /Description for light/);
});

test("emits the default profile first without depending on declaration order", async () => {
  const input = {
    referenceDocument: referenceDocument(),
    profilesDocument: profilesDocument(["dark", "light"]),
    profileDocuments: new Map([
      ["dark", semanticDocument()],
      ["light", semanticDocument()],
    ]),
  };

  const result = await compileDesignTokenDocuments(input);
  const profiles = result.artifacts.get("profiles.ts");

  assert.ok(profiles.indexOf('id: "light"') < profiles.indexOf('id: "dark"'));
});

test("rejects an incomplete non-default profile", async () => {
  const dark = semanticDocument();
  delete dark.color.surface;

  await assert.rejects(
    compileDesignTokenDocuments({
      referenceDocument: referenceDocument(),
      profilesDocument: profilesDocument(["light", "dark"]),
      profileDocuments: new Map([
        ["light", semanticDocument()],
        ["dark", dark],
      ]),
    }),
    /profile dark does not match the semantic token contract; missing: color\.surface/,
  );
});

test("rejects cyclic aliases", async () => {
  const cyclicReference = {
    $schema: schema,
    palette: {
      $type: "color",
      first: {
        $value: "{palette.second}",
      },
      second: {
        $value: "{palette.first}",
      },
    },
  };
  const semantic = {
    $schema: schema,
    color: {
      $type: "color",
      text: {
        $value: "{palette.first}",
      },
    },
  };

  await assert.rejects(
    compileDesignTokenDocuments({
      referenceDocument: cyclicReference,
      profilesDocument: profilesDocument(),
      profileDocuments: new Map([["light", semantic]]),
    }),
    /alias cycle/,
  );
});

test("rejects unresolved aliases", async () => {
  const semantic = semanticDocument({
    missing: {
      $value: "{palette.unknown}",
    },
  });

  await assert.rejects(
    compileDesignTokenDocuments({
      referenceDocument: referenceDocument(),
      profilesDocument: profilesDocument(),
      profileDocuments: new Map([["light", semantic]]),
    }),
    /references unknown token palette\.unknown/,
  );
});

test("rejects aliases that change token type", async () => {
  const semantic = {
    $schema: schema,
    space: {
      $type: "dimension",
      wrong: {
        $value: "{palette.ink}",
      },
    },
  };

  await assert.rejects(
    compileDesignTokenDocuments({
      referenceDocument: referenceDocument(),
      profilesDocument: profilesDocument(),
      profileDocuments: new Map([["light", semantic]]),
    }),
    /cannot alias palette\.ink \(color\)/,
  );
});

test("rejects unsafe CSS extension values", async () => {
  const unsafeReference = referenceDocument({
    space: {
      dangerous: {
        $type: "dimension",
        $value: {
          value: 1,
          unit: "rem",
        },
        $extensions: {
          "org.chimwemwe.css": {
            value: "url(https://example.invalid/value.css)",
          },
        },
      },
    },
  });

  await assert.rejects(
    compileDesignTokenDocuments({
      referenceDocument: unsafeReference,
      profilesDocument: profilesDocument(),
      profileDocuments: new Map([["light", semanticDocument()]]),
    }),
    /CSS extension contains a forbidden construct/,
  );
});

test("rejects unsafe font-family values", async () => {
  const unsafeReference = referenceDocument({
    font: {
      family: {
        $type: "fontFamily",
        $value: "unsafe; color: red",
      },
    },
  });

  await assert.rejects(
    compileDesignTokenDocuments({
      referenceDocument: unsafeReference,
      profilesDocument: profilesDocument(),
      profileDocuments: new Map([["light", semanticDocument()]]),
    }),
    /safe, non-empty font-family names/,
  );
});
