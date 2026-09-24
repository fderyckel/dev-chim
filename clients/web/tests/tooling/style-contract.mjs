import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import postcss from "postcss";

const styleDirectory = path.resolve("src/styles");
const layers = [
  "reset",
  "tokens",
  "base",
  "layout",
  "components",
  "utilities",
  "states",
  "overrides",
];
const implementedLayers = layers.slice(0, -1);
const canonicalLayerOrder = `@layer ${layers.join(", ")};`;
const classPattern =
  /^(?:l|c|u|is|has)-[a-z0-9]+(?:-[a-z0-9]+)*(?:__(?:[a-z0-9]+-?)+)?(?:--(?:[a-z0-9]+-?)+)?$/;
const errors = [];

function report(file, message) {
  errors.push(`${path.relative(process.cwd(), file)}: ${message}`);
}

const indexPath = path.join(styleDirectory, "index.css");
const overridesPath = path.join(styleDirectory, "overrides.css");

if (!fs.existsSync(indexPath)) {
  report(indexPath, "missing stylesheet entry point");
} else {
  const indexSource = fs.readFileSync(indexPath, "utf8");
  if (!indexSource.includes(canonicalLayerOrder)) {
    report(indexPath, `must declare the canonical layer order: ${canonicalLayerOrder}`);
  }

  for (const layer of layers) {
    if (!indexSource.includes(`\"./${layer}.css\"`)) {
      report(indexPath, `must import ${layer}.css`);
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
  const file = path.join(styleDirectory, `${layer}.css`);
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
      if (layer !== "tokens") {
        report(file, `${declaration.prop} must be owned by the tokens layer`);
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
      report(file, `raw colour value in ${declaration.prop} must be a semantic token`);
    }
  });
}

for (const usage of usages) {
  if (!definitions.has(usage.name)) {
    report(usage.file, `uses unknown custom property ${usage.name}`);
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
