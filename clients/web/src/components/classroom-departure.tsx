"use client";

import { useEffect, useRef } from "react";
import { ActionButton } from "../design-system/components/actions";

export function DraftDeparture({
  onStay,
  onDiscard,
}: {
  onStay: () => void;
  onDiscard: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    dialog.current?.showModal();
    dialog.current?.querySelector<HTMLButtonElement>("button")?.focus();
  }, []);
  return (
    <dialog
      ref={dialog}
      className="c-classroom__departure"
      aria-labelledby="departure-title"
      aria-describedby="departure-description"
      onCancel={(event) => {
        event.preventDefault();
        onStay();
      }}
      onKeyDown={(event) => {
        if (event.key !== "Tab") return;
        const buttons = dialog.current?.querySelectorAll<HTMLButtonElement>("button");
        if (!buttons?.length) return;
        const first = buttons[0];
        const last = buttons[buttons.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }}
    >
      <h2 id="departure-title">Discard unsaved marks?</h2>
      <p id="departure-description">
        Stay to keep your marks. Discard removes this draft without saving it.
      </p>
      <div className="c-classroom__actions">
        <ActionButton onClick={onStay}>Stay</ActionButton>
        <ActionButton variant="secondary" onClick={onDiscard}>
          Discard
        </ActionButton>
      </div>
    </dialog>
  );
}
