"use client";

import { useId, useRef } from "react";
import { ActionButton } from "../design-system/components/actions";

export function DemoResetLayout({
  label,
  description,
  onReset,
}: {
  label: string;
  description: string;
  onReset: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  return (
    <>
      <ActionButton variant="quiet" onClick={() => dialog.current?.showModal()}>
        {label}
      </ActionButton>
      <dialog ref={dialog} className="c-demo-layout-dialog" aria-labelledby={titleId}>
        <h2 id={titleId}>{label}?</h2>
        <p>{description} School records and other layouts stay as they are.</p>
        <div className="c-demo-layout-actions">
          <ActionButton variant="secondary" onClick={() => dialog.current?.close()}>
            Cancel
          </ActionButton>
          <ActionButton
            onClick={() => {
              onReset();
              dialog.current?.close();
            }}
          >
            Reset layout
          </ActionButton>
        </div>
      </dialog>
    </>
  );
}
