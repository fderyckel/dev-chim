"use client";

import { useEffect, useRef, useState } from "react";
import { ActionButton, ActionLink } from "../design-system/components/actions";
import { Panel } from "../design-system/components/panel";
import { staffWorkspaceDefaults, staffWorkspaceSections } from "../lib/staff-workspace";
import {
  StaffBlocked,
  StaffFrame,
  StaffRequestError,
  staffRequest,
  staffSession,
  type StaffPreference,
} from "./staff-shared";

export function StaffWorkspace({ page }: { page: "home" | "apps" }) {
  const [presentation, setPresentation] = useState<StaffPreference | null>(null);
  const [csrf, setCsrf] = useState<string | null>(null);
  const [busy, setBusy] = useState(true);
  const [message, setMessage] = useState("Checking your session…");
  const generation = useRef(0);
  const active = useRef(false);

  async function load() {
    const request = ++generation.current;
    const current = () => active.current && request === generation.current;
    setBusy(true);
    setPresentation(null);
    let confirmedToken: string | null = null;
    try {
      const session = await staffSession();
      if (!current()) return;
      confirmedToken = session.csrf_token;
      const own = await staffRequest<StaffPreference>("/api/v1/staff-preferences");
      if (!current()) return;
      setCsrf(confirmedToken);
      setPresentation(own);
      setMessage("");
    } catch (error) {
      if (!current()) return;
      const denied =
        error instanceof StaffRequestError && [401, 403].includes(error.status);
      setCsrf(denied ? null : confirmedToken);
      setMessage(
        denied
          ? "Your access is no longer current. Sign in again."
          : "Your workspace could not be loaded. Try again.",
      );
    } finally {
      if (current()) setBusy(false);
    }
  }

  useEffect(() => {
    active.current = true;
    const arrival = ++generation.current;
    void Promise.resolve().then(() => {
      if (active.current && generation.current === arrival) void load();
    });
    const leave = () => {
      active.current = false;
      generation.current++;
      setPresentation(null);
      setCsrf(null);
    };
    const invalidate = () => {
      active.current = false;
      generation.current++;
    };
    const resume = (event: PageTransitionEvent) => {
      if (event.persisted) window.location.reload();
    };
    window.addEventListener("pagehide", leave);
    window.addEventListener("pageshow", resume);
    return () => {
      invalidate();
      window.removeEventListener("pagehide", leave);
      window.removeEventListener("pageshow", resume);
    };
  }, []);

  const sections = presentation
    ? staffWorkspaceSections(presentation, staffWorkspaceDefaults[page])
    : [];
  return (
    <StaffFrame
      locale="en"
      title={page === "home" ? "Home" : "Apps"}
      description={page === "home" ? "Your available work" : "Find your workspace"}
      csrf={csrf}
      presentation={presentation}
      onSignedOut={() => {
        active.current = false;
        generation.current++;
        setPresentation(null);
        setCsrf(null);
      }}
    >
      {message && (
        <p role="status" className="c-staff__message">
          {message}
        </p>
      )}
      {!busy && !presentation && (
        <>
          <ActionButton variant="secondary" onClick={() => void load()}>
            Try again
          </ActionButton>
          <StaffBlocked locale="en" />
        </>
      )}
      {presentation && (
        <div className="c-staff__workspace-grid">
          {sections.map((section) => (
            <Panel
              eyebrow={page === "home" ? "Home" : "Apps"}
              key={section.id}
              title={section.label}
              titleId={`staff-section-${section.id}`}
            >
              <div className="c-staff__workspace-entries">
                {section.entries.map((entry) => (
                  <div key={entry.id}>
                    <ActionLink href={entry.href} variant="secondary" reloadDocument>
                      {entry.label}
                    </ActionLink>
                    <p>{entry.description}</p>
                  </div>
                ))}
              </div>
            </Panel>
          ))}
          {sections.length === 0 && (
            <p>
              No classroom work is available for this account. Apps and My preferences
              remain available.
            </p>
          )}
        </div>
      )}
    </StaffFrame>
  );
}
