"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { ActionButton } from "../design-system/components/actions";
import { Panel } from "../design-system/components/panel";
import {
  StaffFrame,
  StaffLanguage,
  navigateStaff,
  staffLocale,
  staffRequest,
  translate,
  type StaffLocale,
  type StaffCancelLoginInput,
  type StaffLoginInput,
  type StaffLoginState,
  type StaffReplacePasswordInput,
} from "./staff-shared";

const destinations = new Set(["/accounts", "/classroom", "/first-login/password"]);
const messages = {
  unavailable: [
    "Sign-in is unavailable. Reload the page or contact your account administrator.",
    "La connexion est indisponible. Rechargez la page ou contactez l’administrateur de votre compte.",
  ],
  mismatch: [
    "Use 15–128 characters and enter the same new password twice.",
    "Utilisez entre 15 et 128 caractères et saisissez deux fois le même nouveau mot de passe.",
  ],
  set: [
    "Password set. Sign in with your new password.",
    "Mot de passe défini. Connectez-vous avec votre nouveau mot de passe.",
  ],
  replacement: [
    "We couldn’t set the password. Use a long, uncommon passphrase, confirm it, or ask your account administrator for a new temporary password.",
    "Le mot de passe n’a pas pu être défini. Choisissez une longue phrase secrète peu courante, confirmez-la ou demandez un nouveau mot de passe temporaire à l’administrateur de votre compte.",
  ],
  denied: [
    "We couldn’t sign you in. Check your details or contact your account administrator.",
    "La connexion a échoué. Vérifiez vos identifiants ou contactez l’administrateur de votre compte.",
  ],
} as const;

export function StaffLogin({ replacing = false }: { replacing?: boolean }) {
  const [locale, setLocale] = useState<StaffLocale>("en");
  const [state, setState] = useState<StaffLoginState | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(true);
  const [messageKey, setMessageKey] = useState<keyof typeof messages | null>(null);
  const [invalid, setInvalid] = useState(false);
  const status = useRef<HTMLParagraphElement>(null);
  const t = translate(locale);
  const message = messageKey ? t(messages[messageKey][0], messages[messageKey][1]) : "";

  function navigate(next: StaffLoginState, language = locale) {
    const path = next.next_path;
    if (path && destinations.has(path)) navigateStaff(`${path}?lang=${language}`);
  }

  useEffect(() => {
    let active = true;
    const language = staffLocale(
      new URLSearchParams(window.location.search).get("lang") ?? undefined,
    );
    void staffRequest<StaffLoginState>("/api/v1/staff-login")
      .then((data) => {
        if (!active) return;
        setLocale(language);
        setState(data);
        if (data.stage === "authenticated") {
          const path = data.next_path;
          if (path && destinations.has(path)) navigateStaff(path);
        } else if (replacing && data.stage !== "first_login") {
          navigateStaff(`/sign-in?lang=${language}`);
        } else if (!replacing && data.stage === "first_login") {
          navigateStaff(`/first-login/password?lang=${language}`);
        }
      })
      .catch(() => {
        if (active) setMessageKey("unavailable");
      })
      .finally(() => {
        if (active) setBusy(false);
      });
    return () => {
      active = false;
    };
  }, [replacing]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!state?.csrf_token) return;
    setBusy(true);
    setInvalid(false);
    setMessageKey(null);
    try {
      if (
        replacing &&
        (password.normalize("NFC") !== confirmation.normalize("NFC") ||
          Array.from(password.normalize("NFC")).length < 15 ||
          Array.from(password.normalize("NFC")).length > 128)
      ) {
        setInvalid(true);
        setMessageKey("mismatch");
        status.current?.focus();
        return;
      }
      const next = await staffRequest<StaffLoginState>(
        replacing ? "/api/v1/staff-login/replace-password" : "/api/v1/staff-login",
        replacing
          ? ({
              password,
              confirmation,
              csrf_token: state.csrf_token,
            } satisfies StaffReplacePasswordInput)
          : ({
              email,
              password,
              csrf_token: state.csrf_token,
              locale,
            } satisfies StaffLoginInput),
      );
      setState(next);
      if (replacing && next.stage === "anonymous") {
        setMessageKey("set");
        navigateStaff(`/sign-in?lang=${locale}&password-set=1`);
      } else {
        navigate(next);
      }
    } catch {
      setInvalid(true);
      setMessageKey(replacing ? "replacement" : "denied");
      // A new pre-authentication state may be required after a denied attempt.
      try {
        setState(await staffRequest<StaffLoginState>("/api/v1/staff-login"));
      } catch {
        setState(null);
      }
      status.current?.focus();
    } finally {
      setPassword("");
      setConfirmation("");
      setBusy(false);
    }
  }

  return (
    <StaffFrame
      locale={locale}
      title={
        replacing
          ? t("Choose your password", "Choisissez votre mot de passe")
          : t("Sign in", "Se connecter")
      }
      description={
        replacing
          ? t(
              "Replace your temporary password before opening your work.",
              "Remplacez votre mot de passe temporaire avant d’accéder à votre travail.",
            )
          : t(
              "Use your individual staff account.",
              "Utilisez votre compte personnel de membre du personnel.",
            )
      }
    >
      <div className="c-staff__login">
        <StaffLanguage locale={locale} onChange={setLocale} disabled={busy} />
        <Panel
          eyebrow="Chimwemwe"
          title={
            replacing
              ? t("First sign-in", "Première connexion")
              : t("Staff account", "Compte du personnel")
          }
          titleId="staff-login-title"
        >
          <form
            className="c-staff__form"
            onSubmit={(event) => void submit(event)}
            aria-describedby="staff-login-status"
          >
            {!replacing && (
              <label>
                {t("Email", "Adresse e-mail")}
                <input
                  name="email"
                  type="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  required
                  autoComplete="username"
                  autoCapitalize="none"
                  spellCheck={false}
                  disabled={busy}
                  aria-invalid={invalid}
                />
              </label>
            )}
            {replacing && (
              <p id="staff-password-rules">
                {t(
                  "Use 15–128 characters. A long, uncommon passphrase works well. You can paste or use your password manager.",
                  "Utilisez entre 15 et 128 caractères. Une longue phrase secrète peu courante convient bien. Vous pouvez coller le texte ou utiliser votre gestionnaire de mots de passe.",
                )}
              </p>
            )}
            <label>
              {replacing
                ? t("New password", "Nouveau mot de passe")
                : t("Password", "Mot de passe")}
              <input
                name="password"
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                required
                autoComplete={replacing ? "new-password" : "current-password"}
                autoCapitalize="none"
                spellCheck={false}
                disabled={busy}
                aria-invalid={invalid}
                aria-describedby={
                  replacing
                    ? "staff-password-rules staff-login-status"
                    : "staff-login-status"
                }
              />
            </label>
            {replacing && (
              <label>
                {t("Confirm new password", "Confirmer le nouveau mot de passe")}
                <input
                  name="confirmation"
                  type={showPassword ? "text" : "password"}
                  value={confirmation}
                  onChange={(event) => setConfirmation(event.target.value)}
                  required
                  autoComplete="new-password"
                  autoCapitalize="none"
                  spellCheck={false}
                  disabled={busy}
                  aria-invalid={invalid}
                  aria-describedby="staff-password-rules staff-login-status"
                />
              </label>
            )}
            <ActionButton
              variant="quiet"
              onClick={() => setShowPassword(!showPassword)}
            >
              {showPassword
                ? t("Hide password", "Masquer le mot de passe")
                : t("Show password", "Afficher le mot de passe")}
            </ActionButton>
            <p
              id="staff-login-status"
              ref={status}
              tabIndex={-1}
              role="status"
              aria-live="polite"
              className="c-staff__message"
            >
              {message ||
                (busy
                  ? t("Checking sign-in…", "Vérification de la connexion…")
                  : !replacing &&
                      typeof window !== "undefined" &&
                      new URLSearchParams(window.location.search).has("password-set")
                    ? t(
                        "Password set. Sign in with your new password.",
                        "Mot de passe défini. Connectez-vous avec votre nouveau mot de passe.",
                      )
                    : t(
                        "Contact your account administrator if you need help signing in.",
                        "Contactez l’administrateur de votre compte si vous avez besoin d’aide pour vous connecter.",
                      ))}
            </p>
            <div className="c-staff__actions">
              <ActionButton type="submit" disabled={busy || !state?.csrf_token}>
                {busy
                  ? t("Please wait…", "Veuillez patienter…")
                  : replacing
                    ? t("Set password", "Définir le mot de passe")
                    : t("Sign in", "Se connecter")}
              </ActionButton>
              {replacing && (
                <ActionButton
                  variant="quiet"
                  disabled={busy || !state?.csrf_token}
                  onClick={() => {
                    if (!state?.csrf_token) return;
                    setBusy(true);
                    void staffRequest<StaffLoginState>("/api/v1/staff-login/cancel", {
                      csrf_token: state.csrf_token,
                    } satisfies StaffCancelLoginInput)
                      .then(() => {
                        setPassword("");
                        setConfirmation("");
                        navigateStaff(`/sign-in?lang=${locale}`);
                      })
                      .catch(() => {
                        setMessageKey("unavailable");
                        setBusy(false);
                      });
                  }}
                >
                  {t(
                    "Cancel and return to sign-in",
                    "Annuler et retourner à la connexion",
                  )}
                </ActionButton>
              )}
            </div>
          </form>
        </Panel>
      </div>
    </StaffFrame>
  );
}
