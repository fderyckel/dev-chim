import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import postcss from "postcss";

const styleDirectory = path.resolve("src/styles");
const layers = [
  "reset",
  "tokens",
  "themes",
  "base",
  "layout",
  "components",
  "utilities",
  "states",
  "overrides",
];
const implementedLayers = layers.slice(0, -1);
const canonicalLayerOrder = `@layer ${layers.join(", ")};`;
const layerFiles = new Map([
  ["reset", [path.join(styleDirectory, "reset.css")]],
  ["tokens", [path.resolve("src/design-system/generated/tokens.css")]],
  ["themes", [path.resolve("src/design-system/generated/themes.css")]],
  ["base", [path.join(styleDirectory, "base.css")]],
  ["layout", [path.join(styleDirectory, "layout.css")]],
  [
    "components",
    [
      "shell",
      "primitives",
      "home",
      "structure",
      "preview",
      "bridge",
      "calendar",
      "classroom",
      "model-views",
    ].map((family) => path.join(styleDirectory, "components", `${family}.css`)),
  ],
  ["utilities", [path.join(styleDirectory, "utilities.css")]],
  ["states", [path.join(styleDirectory, "states.css")]],
  ["overrides", [path.join(styleDirectory, "overrides.css")]],
]);
const layerImports = new Map([
  ["reset", ["./reset.css"]],
  ["tokens", ["../design-system/generated/tokens.css"]],
  ["themes", ["../design-system/generated/themes.css"]],
  ["base", ["./base.css"]],
  ["layout", ["./layout.css"]],
  [
    "components",
    [
      "shell",
      "primitives",
      "home",
      "structure",
      "preview",
      "bridge",
      "calendar",
      "classroom",
      "model-views",
    ].map((family) => `./components/${family}.css`),
  ],
  ["utilities", ["./utilities.css"]],
  ["states", ["./states.css"]],
  ["overrides", ["./overrides.css"]],
]);
const customPropertyOwnerLayers = new Set(["tokens", "themes"]);
const componentStyleDirectory = path.join(styleDirectory, "components");
const rawPrimitivePattern = /\bc-(?:button|page-heading|panel|status)(?![_-])/;
const classPattern =
  /^(?:l|c|u|is|has)-[a-z0-9]+(?:-[a-z0-9]+)*(?:__(?:[a-z0-9]+-?)+)?(?:--(?:[a-z0-9]+-?)+)?$/;
const errors = [];

function report(file, message) {
  errors.push(`${path.relative(process.cwd(), file)}: ${message}`);
}

const indexPath = path.join(styleDirectory, "index.css");
const overridesPath = path.join(styleDirectory, "overrides.css");

const expectedComponentFiles = new Set(
  layerFiles.get("components").map((file) => path.basename(file)),
);
const actualComponentFiles = fs.existsSync(componentStyleDirectory)
  ? fs
      .readdirSync(componentStyleDirectory)
      .filter((file) => file.endsWith(".css"))
      .sort()
  : [];
for (const file of actualComponentFiles) {
  if (!expectedComponentFiles.has(file)) {
    report(
      path.join(componentStyleDirectory, file),
      "component family is not registered",
    );
  }
}

if (!fs.existsSync(indexPath)) {
  report(indexPath, "missing stylesheet entry point");
} else {
  const indexSource = fs.readFileSync(indexPath, "utf8");
  if (!indexSource.includes(canonicalLayerOrder)) {
    report(indexPath, `must declare the canonical layer order: ${canonicalLayerOrder}`);
  }

  for (const layer of layers) {
    for (const importPath of layerImports.get(layer)) {
      if (!indexSource.includes(`\"${importPath}\"`)) {
        report(indexPath, `must import ${importPath}`);
      }
    }
  }
}

if (!fs.existsSync(overridesPath)) {
  report(overridesPath, "missing reserved overrides layer stylesheet");
} else {
  const overridesRoot = postcss.parse(fs.readFileSync(overridesPath, "utf8"), {
    from: overridesPath,
  });
  const materialNodes = overridesRoot.nodes.filter((node) => node.type !== "comment");
  const overrideLayer = materialNodes[0];
  const hasOnlyComments =
    overrideLayer?.type === "atrule" &&
    overrideLayer.name === "layer" &&
    overrideLayer.params.trim() === "overrides" &&
    overrideLayer.nodes?.every((node) => node.type === "comment");

  if (materialNodes.length !== 1 || !hasOnlyComments) {
    report(overridesPath, "must remain empty during UI-0");
  }
}

const definitions = new Map();
const usages = [];

for (const layer of implementedLayers) {
  for (const file of layerFiles.get(layer)) {
    if (!fs.existsSync(file)) {
      report(file, `missing ${layer} layer stylesheet`);
      continue;
    }

    const source = fs.readFileSync(file, "utf8");
    const root = postcss.parse(source, { from: file });
    const materialNodes = root.nodes.filter((node) => node.type !== "comment");
    const matchingLayerBlocks = materialNodes.filter(
      (node) =>
        node.type === "atrule" &&
        node.name === "layer" &&
        node.params.trim() === layer &&
        node.nodes !== undefined,
    );

    if (matchingLayerBlocks.length !== 1 || materialNodes.length !== 1) {
      report(file, `all rules must be contained in one @layer ${layer} block`);
    }

    root.walkRules((rule) => {
      for (const match of rule.selector.matchAll(/\.([a-zA-Z_][\w-]*)/g)) {
        if (!classPattern.test(match[1])) {
          report(file, `class .${match[1]} does not follow the ownership grammar`);
        }
      }
    });

    root.walkDecls((declaration) => {
      if (declaration.prop.startsWith("--")) {
        definitions.set(declaration.prop, file);
        if (!customPropertyOwnerLayers.has(layer)) {
          report(
            file,
            `${declaration.prop} must be owned by the tokens or themes layer`,
          );
        }
      }

      for (const match of declaration.value.matchAll(/var\((--[a-zA-Z0-9-_]+)/g)) {
        usages.push({ name: match[1], file });
      }

      if (
        layer !== "tokens" &&
        /#[0-9a-f]{3,8}\b|\b(?:rgb|hsl|hwb|lab|lch|oklab|oklch|color)\(/i.test(
          declaration.value,
        )
      ) {
        report(
          file,
          `raw colour value in ${declaration.prop} must be a semantic token`,
        );
      }

      if (
        !customPropertyOwnerLayers.has(layer) &&
        /var\(--palette-/.test(declaration.value)
      ) {
        report(
          file,
          `reference palette use in ${declaration.prop} must go through a semantic token`,
        );
      }
    });
  }
}

for (const usage of usages) {
  if (!definitions.has(usage.name)) {
    report(usage.file, `uses unknown custom property ${usage.name}`);
  }
}

for (const sourceDirectory of [path.resolve("app"), path.resolve("src/components")]) {
  const sourceFiles = fs
    .readdirSync(sourceDirectory, { recursive: true })
    .filter((file) => typeof file === "string" && file.endsWith(".tsx"));

  for (const relativeFile of sourceFiles) {
    const file = path.join(sourceDirectory, relativeFile);
    const source = fs.readFileSync(file, "utf8");
    if (rawPrimitivePattern.test(source)) {
      report(
        file,
        "must consume page headings, panels, statuses, and actions through design-system components",
      );
    }
  }
}

if (errors.length > 0) {
  console.error("CSS contract check failed:\n");
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(
  `CSS contract check passed (${implementedLayers.length} layers, ${definitions.size} tokens).`,
);
