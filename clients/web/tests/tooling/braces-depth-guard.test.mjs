import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const braces = createRequire(require.resolve("micromatch"))("braces");

test("preserves ordinary brace compilation and expansion", () => {
  assert.deepEqual(braces("src/{app,components}/**/*.tsx"), [
    "src/(app|components)/**/*.tsx",
  ]);
  assert.deepEqual(braces.expand("term-{1..3}"), ["term-1", "term-2", "term-3"]);
});

test("rejects deeply nested patterns before recursive walkers run", () => {
  const deeplyNested = `${"{".repeat(101)}a,b${"}".repeat(101)}`;
  const expected = /Pattern nesting depth \(101\) exceeds maximum \(100\)/;

  assert.throws(() => braces(deeplyNested), expected);
  assert.throws(() => braces.expand(deeplyNested), expected);
  assert.throws(() => braces(`${"(".repeat(101)}a${")".repeat(101)}`), expected);
});

test("does not allow callers to raise the fixed nesting ceiling", () => {
  const deeplyNested = `${"{".repeat(101)}a,b${"}".repeat(101)}`;

  assert.throws(
    () => braces(deeplyNested, { maxDepth: 10_000 }),
    /Pattern nesting depth \(101\) exceeds maximum \(100\)/,
  );
});

test("rejects deeply nested and cyclic AST inputs at every recursive entry point", () => {
  const root = { type: "root", nodes: [] };
  let current = root;

  for (let depth = 0; depth < 101; depth += 1) {
    const child = { type: "brace", nodes: [] };
    current.nodes.push(child);
    current = child;
  }

  const expected = /Pattern nesting depth \(101\) exceeds maximum \(100\)/;
  assert.throws(() => braces.compile(root), expected);
  assert.throws(() => braces.expand(root), expected);
  assert.throws(() => braces.stringify(root), expected);

  const cyclic = { type: "root", nodes: [] };
  cyclic.nodes.push(cyclic);
  assert.throws(() => braces.compile(cyclic), /Brace AST must not contain cycles/);
});

test("compiles AST inputs without writing pattern fragments to stdout", () => {
  const messages = [];
  const originalLog = console.log;
  console.log = (...values) => messages.push(values);

  try {
    assert.equal(
      braces.compile({
        type: "root",
        nodes: [{ isClose: true, value: "private-pattern-fragment" }],
      }),
      "private-pattern-fragment",
    );
  } finally {
    console.log = originalLog;
  }

  assert.deepEqual(messages, []);
});
