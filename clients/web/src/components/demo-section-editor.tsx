"use client";

import { useEffect, useId, useState } from "react";
import { ActionButton } from "../design-system/components/actions";
import {
  copySections,
  moveLayoutItem,
  nextLayoutId,
  reorder,
  temporaryLayoutNotice,
  validLayoutLabel,
  validLayoutSections,
  type DemoLayoutSection,
  type DemoPageId,
} from "../lib/demo-layout";
import type { DemoDestination } from "../lib/demo-navigation";

type EditorProps = {
  kind: "apps" | "home";
  initialSections: DemoLayoutSection[];
  initialName?: string;
  reservedNames?: readonly string[];
  destinations: readonly DemoDestination[];
  onApply: (sections: DemoLayoutSection[], name: string) => void;
  onCancel: () => void;
};

export function DemoSectionEditor({
  kind,
  initialSections,
  initialName = "",
  reservedNames = [],
  destinations,
  onApply,
  onCancel,
}: EditorProps) {
  const [sections, setSections] = useState(() => copySections(initialSections));
  const [name, setName] = useState(initialName);
  const [preview, setPreview] = useState(false);
  const [attempted, setAttempted] = useState(false);
  const [message, setMessage] = useState("");
  const prefix = useId();
  const [initial] = useState(() =>
    JSON.stringify({ sections: initialSections, name: initialName }),
  );
  const dirty = JSON.stringify({ sections, name }) !== initial;
  const invalidName =
    kind === "home" &&
    (!validLayoutLabel(name) ||
      reservedNames.some(
        (reserved) =>
          reserved.trim().toLocaleLowerCase() === name.trim().toLocaleLowerCase(),
      ));
  const invalid = !validLayoutSections(sections) || invalidName;
  const invalidSectionName = (section: DemoLayoutSection) =>
    !validLayoutLabel(section.label) ||
    sections.some(
      (other) =>
        other.id !== section.id &&
        other.label.trim().toLocaleLowerCase() ===
          section.label.trim().toLocaleLowerCase(),
    );
  const noun = kind === "apps" ? "Navigation group" : "Home section";
  const title = kind === "apps" ? "Organize apps" : "Customize my Home";
  const labelOf = (id: DemoPageId) =>
    destinations.find((destination) => destination.id === id)!.label;
  const itemId = (sectionId: string, pageId: DemoPageId) =>
    `${prefix}-${sectionId}-${pageId}`;
  const focus = (id: string) =>
    requestAnimationFrame(() => document.getElementById(id)?.focus());

  useEffect(() => {
    document.getElementById(`${prefix}-title`)?.focus();
  }, [prefix]);

  useEffect(() => {
    if (!dirty) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);

  function change(next: DemoLayoutSection[], announcement?: string) {
    setSections(next);
    setPreview(false);
    if (announcement) setMessage(announcement);
  }

  function addSection() {
    const id = nextLayoutId(
      "section",
      sections.map((section) => section.id),
    );
    let label = `New ${kind === "apps" ? "group" : "section"}`;
    let count = 2;
    while (
      sections.some(
        (section) => section.label.toLocaleLowerCase() === label.toLocaleLowerCase(),
      )
    )
      label = `New ${kind === "apps" ? "group" : "section"} ${count++}`;
    change(
      [...sections, { id, label, items: [] }],
      `${noun} added, position ${sections.length + 1}.`,
    );
    focus(`${prefix}-${id}-label`);
  }

  function apply(showPreview: boolean) {
    setAttempted(true);
    if (invalid) {
      const firstInvalidSection = sections.find(invalidSectionName);
      focus(
        invalidName ? `${prefix}-name` : `${prefix}-${firstInvalidSection?.id}-label`,
      );
      return;
    }
    if (showPreview) {
      setPreview(true);
      setMessage("Preview shown. The applied layout has not changed.");
    } else {
      onApply(
        sections.map((section) => ({ ...section, label: section.label.trim() })),
        name.trim(),
      );
    }
  }

  return (
    <section className="c-demo-layout-editor" aria-labelledby={`${prefix}-title`}>
      <header className="c-demo-layout-heading">
        <h2 id={`${prefix}-title`} tabIndex={-1}>
          {title}
        </h2>
        <p className="c-demo-muted">
          {kind === "apps"
            ? "Demo institution navigation preview. Personal Home layouts stay separate."
            : "Arrange your personal landing screen. App groups stay separate."}
        </p>
        <p className="c-demo-muted">{temporaryLayoutNotice}</p>
      </header>
      <p className="c-demo-muted">
        {dirty ? "Unapplied draft" : "Draft"} · Leaving this page discards unapplied
        changes.
      </p>
      {attempted && invalid ? (
        <p id={`${prefix}-error`} role="alert">
          Use distinct, nonblank names of up to 60 characters, without markup. Choose
          only available pages.
        </p>
      ) : null}
      {kind === "home" ? (
        <label className="c-field">
          Layout name
          <input
            id={`${prefix}-name`}
            maxLength={60}
            value={name}
            onChange={(event) => {
              setName(event.target.value);
              setPreview(false);
            }}
            aria-invalid={attempted && invalidName}
            aria-describedby={attempted && invalidName ? `${prefix}-error` : undefined}
          />
        </label>
      ) : null}
      {sections.length === 0 ? (
        <p>No sections yet. Add a section, or Cancel to keep the current layout.</p>
      ) : null}
      {sections.map((section, sectionIndex) => (
        <fieldset className="c-demo-layout-section" key={section.id}>
          <legend>
            {noun} {sectionIndex + 1}
          </legend>
          <label className="c-field" htmlFor={`${prefix}-${section.id}-label`}>
            {noun} {sectionIndex + 1} name
          </label>
          <input
            id={`${prefix}-${section.id}-label`}
            maxLength={60}
            value={section.label}
            aria-invalid={attempted && invalidSectionName(section)}
            aria-describedby={
              attempted && invalidSectionName(section) ? `${prefix}-error` : undefined
            }
            onChange={(event) =>
              change(
                sections.map((candidate) =>
                  candidate.id === section.id
                    ? { ...candidate, label: event.target.value }
                    : candidate,
                ),
              )
            }
          />
          <div className="c-demo-layout-actions">
            <ActionButton
              variant="quiet"
              disabled={sectionIndex === 0}
              onClick={() => {
                change(
                  reorder(sections, sectionIndex, -1),
                  `${section.label} moved to position ${sectionIndex}.`,
                );
                focus(`${prefix}-${section.id}-label`);
              }}
            >
              Move section up
            </ActionButton>
            <ActionButton
              variant="quiet"
              disabled={sectionIndex === sections.length - 1}
              onClick={() => {
                change(
                  reorder(sections, sectionIndex, 1),
                  `${section.label} moved to position ${sectionIndex + 2}.`,
                );
                focus(`${prefix}-${section.id}-label`);
              }}
            >
              Move section down
            </ActionButton>
            <ActionButton
              variant="quiet"
              onClick={() => {
                change(
                  sections.filter((candidate) => candidate.id !== section.id),
                  `${section.label} removed from this layout.`,
                );
                focus(
                  sections.length > 1
                    ? `${prefix}-${sections[sectionIndex === 0 ? 1 : sectionIndex - 1].id}-label`
                    : `${prefix}-add`,
                );
              }}
            >
              Remove section
            </ActionButton>
          </div>
          <p className="c-demo-muted">
            Removing a section removes its shortcuts from this layout only.
          </p>
          <ol className="c-demo-layout-items">
            {section.items.map((pageId, index) => (
              <li key={pageId} id={itemId(section.id, pageId)} tabIndex={-1}>
                <strong>{labelOf(pageId)}</strong>
                <span className="c-demo-muted">
                  Position {index + 1} of {section.items.length}
                </span>
                <div className="c-demo-layout-actions">
                  <ActionButton
                    variant="quiet"
                    disabled={index === 0}
                    onClick={() => {
                      change(
                        sections.map((candidate) =>
                          candidate.id === section.id
                            ? {
                                ...candidate,
                                items: reorder(candidate.items, index, -1),
                              }
                            : candidate,
                        ),
                        `${labelOf(pageId)} moved to position ${index} in ${section.label}.`,
                      );
                      focus(itemId(section.id, pageId));
                    }}
                  >
                    Move up
                  </ActionButton>
                  <ActionButton
                    variant="quiet"
                    disabled={index === section.items.length - 1}
                    onClick={() => {
                      change(
                        sections.map((candidate) =>
                          candidate.id === section.id
                            ? {
                                ...candidate,
                                items: reorder(candidate.items, index, 1),
                              }
                            : candidate,
                        ),
                        `${labelOf(pageId)} moved to position ${index + 2} in ${section.label}.`,
                      );
                      focus(itemId(section.id, pageId));
                    }}
                  >
                    Move down
                  </ActionButton>
                  <ActionButton
                    variant="quiet"
                    onClick={() => {
                      change(
                        sections.map((candidate) =>
                          candidate.id === section.id
                            ? {
                                ...candidate,
                                items: candidate.items.filter(
                                  (item) => item !== pageId,
                                ),
                              }
                            : candidate,
                        ),
                        `${labelOf(pageId)} removed from ${section.label}.`,
                      );
                      focus(`${prefix}-${section.id}-label`);
                    }}
                  >
                    Remove
                  </ActionButton>
                </div>
                <label className="c-field">
                  Move {labelOf(pageId)} to section
                  <select
                    value=""
                    onChange={(event) => {
                      const target = sections.find(
                        (candidate) => candidate.id === event.target.value,
                      );
                      if (!target) return;
                      change(
                        moveLayoutItem(sections, section.id, pageId, target.id),
                        `${labelOf(pageId)} moved to ${target.label}, position ${target.items.length + 1}.`,
                      );
                      focus(itemId(target.id, pageId));
                    }}
                  >
                    <option value="">Choose a section</option>
                    {sections
                      .filter(
                        (candidate) =>
                          candidate.id !== section.id &&
                          !candidate.items.includes(pageId),
                      )
                      .map((candidate) => (
                        <option key={candidate.id} value={candidate.id}>
                          {candidate.label || "Unnamed section"}
                        </option>
                      ))}
                  </select>
                </label>
              </li>
            ))}
          </ol>
          <label className="c-field">
            Add page to {section.label || "unnamed section"}
            <select
              value=""
              disabled={section.items.length === destinations.length}
              onChange={(event) => {
                const pageId = event.target.value as DemoPageId;
                if (
                  !destinations.some((destination) => destination.id === pageId) ||
                  section.items.includes(pageId)
                )
                  return;
                change(
                  sections.map((candidate) =>
                    candidate.id === section.id
                      ? { ...candidate, items: [...candidate.items, pageId] }
                      : candidate,
                  ),
                  `${labelOf(pageId)} added to ${section.label}, position ${section.items.length + 1}.`,
                );
                focus(itemId(section.id, pageId));
              }}
            >
              <option value="">Choose a page to add</option>
              {destinations
                .filter(
                  (destination) =>
                    !section.items.includes(destination.id as DemoPageId),
                )
                .map((destination) => (
                  <option key={destination.id} value={destination.id}>
                    {destination.label}
                  </option>
                ))}
            </select>
          </label>
        </fieldset>
      ))}
      <ActionButton
        variant="secondary"
        id={`${prefix}-add`}
        disabled={sections.length >= 8}
        onClick={addSection}
      >
        Add {kind === "apps" ? "navigation group" : "Home section"}
      </ActionButton>
      <p className="c-demo-muted">
        Up to eight sections. The same page can have a shortcut in several sections.
      </p>
      <p role="status" className="c-demo-layout-announcement">
        {message}
      </p>
      {preview ? (
        <section className="c-demo-layout-preview" aria-label="Layout preview">
          <h3>{kind === "home" ? name : "App organization preview"}</h3>
          {sections.map((section) => (
            <div key={section.id}>
              <h4>{section.label}</h4>
              <ul>
                {section.items.map((pageId) => (
                  <li key={pageId}>{labelOf(pageId)}</li>
                ))}
              </ul>
              {!section.items.length ? (
                <p className="c-demo-muted">No shortcuts in this section.</p>
              ) : null}
            </div>
          ))}
        </section>
      ) : null}
      <div className="c-demo-layout-actions">
        <ActionButton onClick={() => apply(false)}>Apply layout</ActionButton>
        <ActionButton variant="secondary" onClick={() => apply(true)}>
          Preview layout
        </ActionButton>
        <ActionButton variant="quiet" onClick={onCancel}>
          Cancel
        </ActionButton>
      </div>
    </section>
  );
}
