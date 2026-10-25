"use client";

import { useEffect, useState, type ReactNode } from "react";
import { ActionButton, ActionLink } from "../design-system/components/actions";
import { PageHeading } from "../design-system/components/page-heading";
import type { components, paths } from "../generated/public/staff-schema";
import type { components as SessionComponents } from "../generated/public/session-schema";

export type StaffLocale = "en" | "en-MW" | "fr";
export type StaffAccount = components["schemas"]["StaffAccount"];
export type StaffInventory = components["schemas"]["StaffAccountsResponse"]["data"];
export type StaffLoginState = components["schemas"]["StaffLoginResponse"]["data"];
export type StaffReceipt = components["schemas"]["StaffAccountActionResponse"]["data"];
export type StaffPreference = components["schemas"]["StaffPreferencesResponse"]["data"];
export type StaffLoginInput = components["schemas"]["StaffLoginRequest"];
export type StaffCancelLoginInput = components["schemas"]["StaffCancelLoginRequest"];
export type StaffReplacePasswordInput =
  components["schemas"]["StaffReplacePasswordRequest"];
export type StaffPreferencesInput = components["schemas"]["StaffPreferencesRequest"];
type WithoutReferences<T> = Omit<T, "idempotency_key" | "causation_id">;
export type StaffActionInput =
  | WithoutReferences<components["schemas"]["StaffProvisionRequest"]>
  | WithoutReferences<components["schemas"]["StaffReviseDetailsRequest"]>
  | WithoutReferences<components["schemas"]["StaffSetAccessRequest"]>
  | WithoutReferences<components["schemas"]["StaffTargetRequest"]>;

export const translate = (locale: StaffLocale) => (en: string, fr: string) =>
  locale === "fr" ? fr : en;
export const staffLocale = (value?: string): StaffLocale =>
  value === "fr" ? "fr" : value === "en-MW" ? "en-MW" : "en";

export class StaffRequestError extends Error {
  constructor(
    readonly status: number,
    readonly code?: string,
  ) {
    super("Staff request was not confirmed");
  }
}

type StaffPath = keyof paths | "/api/v1/session" | "/api/v1/session/logout";

export async function staffRequest<T>(
  path: StaffPath,
  body?: object,
  csrf?: string,
): Promise<T> {
  const response = await fetch(path, {
    method: body ? "POST" : "GET",
    credentials: "same-origin",
    cache: "no-store",
    headers: {
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
      ...(csrf ? { "X-CSRF-Token": csrf } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (response.status === 204) return undefined as T;
  const result = (await response.json()) as {
    data?: T;
    errors?: { code?: string }[];
  };
  if (!response.ok || !result.data)
    throw new StaffRequestError(response.status, result.errors?.[0]?.code);
  return result.data;
}

export async function staffSession() {
  return staffRequest<SessionComponents["schemas"]["SessionData"]>("/api/v1/session");
}

export function actionReferences() {
  return { idempotency_key: crypto.randomUUID(), causation_id: crypto.randomUUID() };
}

export function navigateStaff(path: string) {
  if (
    ![
      "/accounts",
      "/classroom",
      "/sign-in",
      "/first-login/password",
      "/my-preferences",
    ].includes(path.split("?")[0])
  )
    return;
  // Authentication transitions discard the credential form and client navigation cache.
  window.location.assign(path);
}

export function useStaffLanguage(locale: StaffLocale) {
  useEffect(() => {
    document.documentElement.lang = locale;
    return () => {
      document.documentElement.lang = "en";
    };
  }, [locale]);
  // A restored browser snapshot must recheck writer-owned access before showing records.
  useEffect(() => {
    const refresh = (event: PageTransitionEvent) => {
      if (event.persisted) window.location.reload();
    };
    window.addEventListener("pageshow", refresh);
    return () => window.removeEventListener("pageshow", refresh);
  }, []);
}

export function StaffLanguage({
  locale,
  onChange,
  disabled = false,
  displayLocale = locale,
}: {
  locale: StaffLocale;
  onChange: (locale: StaffLocale) => void;
  disabled?: boolean;
  displayLocale?: StaffLocale;
}) {
  const t = translate(displayLocale);
  return (
    <label className="c-staff__language">
      {t("System language", "Langue du système")}
      <select
        value={locale}
        onChange={(event) => onChange(staffLocale(event.target.value))}
        disabled={disabled}
        autoComplete="language"
      >
        <option value="en" lang="en">
          English
        </option>
        <option value="en-MW" lang="en-MW">
          English (Malawi)
        </option>
        <option value="fr" lang="fr">
          Français
        </option>
      </select>
    </label>
  );
}

export function StaffHelp({
  id,
  label,
  children,
}: {
  id: string;
  label: string;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(false);
  return (
    <div className="c-staff__help">
      <button
        type="button"
        className="c-staff__help-toggle"
        aria-label={label}
        aria-expanded={open}
        aria-controls={id}
        onClick={() => setOpen(!open)}
        onKeyDown={(event) => {
          if (event.key === "Escape") setOpen(false);
        }}
      >
        ?
      </button>
      {open && <p id={id}>{children}</p>}
    </div>
  );
}

export function StaffFrame({
  locale,
  title,
  description,
  csrf,
  institution,
  onSignedOut,
  children,
}: {
  locale: StaffLocale;
  title: string;
  description: string;
  csrf?: string | null;
  institution?: string;
  onSignedOut?: () => void;
  children: ReactNode;
}) {
  const t = translate(locale);
  const [logoutError, setLogoutError] = useState(false);
  const [signingOut, setSigningOut] = useState(false);
  useStaffLanguage(locale);
  return (
    <main className="c-staff" lang={locale}>
      <PageHeading
        eyebrow={institution ?? "Chimwemwe"}
        title={title}
        description={description}
        aside={
          <p>
            {t(
              "Fictional staff · local evaluation",
              "Personnel fictif · évaluation locale",
            )}
          </p>
        }
      />
      {csrf && (
        <nav
          className="c-staff__actions"
          aria-label={t("Staff navigation", "Navigation du personnel")}
        >
          <ActionLink href="/accounts" variant="quiet">
            {t("Accounts", "Comptes")}
          </ActionLink>
          <ActionLink href="/classroom" variant="quiet">
            {t("My classes", "Mes classes")}
          </ActionLink>
          <ActionLink href="/my-preferences" variant="quiet">
            {t("My preferences", "Mes préférences")}
          </ActionLink>
          <ActionButton
            variant="quiet"
            disabled={signingOut}
            onClick={() => {
              setSigningOut(true);
              void staffRequest("/api/v1/session/logout", {}, csrf)
                .then(() => {
                  onSignedOut?.();
                  navigateStaff("/sign-in");
                })
                .catch(() => {
                  setLogoutError(true);
                  setSigningOut(false);
                });
            }}
          >
            {t("Sign out", "Se déconnecter")}
          </ActionButton>
        </nav>
      )}
      {logoutError && (
        <p role="alert" className="c-staff__message">
          {t(
            "Sign-out could not be confirmed. Try again before leaving a shared device.",
            "La déconnexion n’a pas pu être confirmée. Réessayez avant de quitter un appareil partagé.",
          )}
        </p>
      )}
      {children}
    </main>
  );
}

export function StaffBlocked({ locale }: { locale: StaffLocale }) {
  const t = translate(locale);
  return (
    <div className="c-staff__actions">
      <ActionLink href="/sign-in">{t("Sign in", "Se connecter")}</ActionLink>
      <p>
        {t(
          "Contact your account administrator if you need access.",
          "Contactez l’administrateur de votre compte si vous avez besoin d’un accès.",
        )}
      </p>
    </div>
  );
}

export function staffActionMessage(error: unknown, locale: StaffLocale) {
  const t = translate(locale);
  if (error instanceof StaffRequestError) {
    if (error.status === 401 || error.status === 403)
      return t(
        "You don’t have current access to this action. Sign in again or contact your account administrator.",
        "Vous n’avez pas accès à cette action actuellement. Reconnectez-vous ou contactez l’administrateur de votre compte.",
      );
    if (error.status === 409)
      return t(
        "The account changed. Reload its current status before continuing.",
        "Le compte a changé. Rechargez son état actuel avant de continuer.",
      );
    if (error.status === 422 || error.status === 400)
      return t(
        "The change was not accepted. Check the details and reload the current status.",
        "La modification a été refusée. Vérifiez les informations et rechargez l’état actuel.",
      );
  }
  return t(
    "Status could not be confirmed. Reload before trying another action. A generated password cannot be displayed again.",
    "L’état n’a pas pu être confirmé. Rechargez avant toute autre action. Un mot de passe généré ne peut pas être réaffiché.",
  );
}
