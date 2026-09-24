"use client";

import { useState } from "react";

import type { InterfaceState, InterfaceStateKey } from "../ports/view-data";

type InterfaceStateExplorerProps = Readonly<{
  states: ReadonlyArray<InterfaceState>;
}>;

export function InterfaceStateExplorer({ states }: InterfaceStateExplorerProps) {
  const [selectedKey, setSelectedKey] = useState<InterfaceStateKey>("ready");
  const selectedState = states.find((state) => state.key === selectedKey) ?? states[0];

  function resetState() {
    setSelectedKey("ready");
  }

  if (!selectedState) {
    return null;
  }

  return (
    <div className="c-state-explorer">
      <div className="c-state-explorer__controls">
        <p className="c-state-explorer__instruction" id="state-instruction">
          Choose an interface response to inspect its plain-language message and
          recovery guidance.
        </p>
        <div
          className="c-state-picker"
          role="group"
          aria-labelledby="state-instruction"
        >
          {states.map((state) => (
            <button
              className={`c-state-picker__button${
                state.key === selectedState.key ? " is-selected" : ""
              }`}
              type="button"
              key={state.key}
              onClick={() => setSelectedKey(state.key)}
              aria-pressed={state.key === selectedState.key}
            >
              {state.label}
            </button>
          ))}
        </div>
      </div>

      <div
        className={`c-state-notice is-${selectedState.key}`}
        data-tone={selectedState.tone}
        role="status"
        aria-live="polite"
        aria-atomic="true"
      >
        <div
          className={`c-state-notice__symbol is-${selectedState.tone}`}
          aria-hidden="true"
        >
          {selectedState.key === "loading" ? (
            <span className="c-spinner is-loading" />
          ) : (
            <span className="c-state-notice__glyph">
              {selectedState.tone === "positive"
                ? "✓"
                : selectedState.tone === "critical"
                  ? "!"
                  : "i"}
            </span>
          )}
        </div>
        <div className="c-state-notice__body">
          <p className="c-state-notice__label">{selectedState.label}</p>
          <h3 className="c-state-notice__title">{selectedState.title}</h3>
          <p className="c-state-notice__description">{selectedState.description}</p>
          <p className="c-state-notice__recovery">
            <strong>What to do:</strong> {selectedState.recovery}
          </p>
        </div>
        {selectedState.key !== "ready" ? (
          <button
            className="c-button c-button--secondary"
            type="button"
            onClick={resetState}
          >
            Return to ready
          </button>
        ) : null}
      </div>
    </div>
  );
}
