"use client";
import { useState } from "react";
import { ActionButton } from "../design-system/components/actions";
export function CommunicationsProofPersonas({
  disabled = false,
}: {
  disabled?: boolean;
}) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  async function select(name: string) {
    setBusy(true);
    try {
      const result = await fetch("/proof/persona/" + name, {
        method: "POST",
        credentials: "same-origin",
        cache: "no-store",
      });
      if (!result.ok) throw new Error("Unavailable");
      window.location.reload();
    } catch {
      setMessage("The fictional persona is unavailable.");
      setBusy(false);
    }
  }
  return (
    <details>
      <summary>Fictional proof personas</summary>
      <p>This isolated test harness supplies separate fictional sessions.</p>
      <div className="c-staff__actions">
        {["author", "approver", "recipient"].map((name) => (
          <ActionButton
            key={name}
            onClick={() => void select(name)}
            disabled={busy || disabled}
            variant="secondary"
          >
            Use fictional {name}
          </ActionButton>
        ))}
      </div>
      <p role="status">{message}</p>
    </details>
  );
}
