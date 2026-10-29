"use client";

import { useEffect, useState } from "react";
import { ActionButton } from "../design-system/components/actions";
import { Panel } from "../design-system/components/panel";
import {
  StaffBlocked,
  StaffFrame,
  StaffLanguage,
  actionReferences,
  staffActionMessage,
  staffLocale,
  staffRequest,
  staffSession,
  translate,
  type StaffLocale,
  type StaffPreference,
  type StaffPreferencesInput,
  type StaffReceipt,
} from "./staff-shared";

export function StaffPreferences() {
  const [locale, setLocale] = useState<StaffLocale>("en");
  const [saved, setSaved] = useState<StaffPreference | null>(null);
  const [csrf, setCsrf] = useState<string | null>(null);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(true);
  const [uncertain, setUncertain] = useState(false);
  const t = translate(locale);

  async function load() {
    setBusy(true);
    let authenticated = false;
    try {
      const session = await staffSession();
      authenticated = true;
      setCsrf(session.csrf_token);
      const data = await staffRequest<StaffPreference>("/api/v1/staff-preferences");
      setSaved(data);
      setLocale(staffLocale(data.locale));
      setUncertain(false);
      setMessage(
        translate(staffLocale(data.locale))(
          "Your current preferences are loaded.",
          "Vos préférences actuelles sont chargées.",
        ),
      );
    } catch (error) {
      setSaved(null);
      if (!authenticated) setCsrf(null);
      setMessage(staffActionMessage(error, locale));
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    void Promise.resolve().then(() => load());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const clear = () => {
      setSaved(null);
      setCsrf(null);
    };
    window.addEventListener("pagehide", clear);
    return () => window.removeEventListener("pagehide", clear);
  }, []);

  return (
    <StaffFrame
      locale={locale}
      title={t("My preferences", "Mes préférences")}
      description={t(
        "Choose the language you use in Chimwemwe.",
        "Choisissez la langue que vous utilisez dans Chimwemwe.",
      )}
      csrf={csrf}
      presentation={saved}
      onSignedOut={() => {
        setCsrf(null);
        setSaved(null);
      }}
    >
      <p className="c-staff__message" role="status" aria-live="polite">
        {message || t("Checking your preferences…", "Vérification de vos préférences…")}
      </p>
      {saved && csrf ? (
        <Panel
          eyebrow={saved.display_name}
          title={t("System language", "Langue du système")}
          titleId="staff-preferences-title"
        >
          <form
            className="c-staff__form"
            onSubmit={(event) => {
              event.preventDefault();
              setBusy(true);
              void staffRequest<StaffReceipt>(
                "/api/v1/staff-preferences",
                {
                  locale,
                  expected_version: saved.lock_version,
                  ...actionReferences(),
                } satisfies StaffPreferencesInput,
                csrf,
              )
                .then(() => staffRequest<StaffPreference>("/api/v1/staff-preferences"))
                .then((data) => {
                  setSaved(data);
                  setLocale(staffLocale(data.locale));
                  setMessage(
                    translate(staffLocale(data.locale))(
                      "Preferences saved. Your access has not changed.",
                      "Préférences enregistrées. Votre accès est inchangé.",
                    ),
                  );
                })
                .catch((error) => {
                  setMessage(staffActionMessage(error, locale));
                  setUncertain(true);
                })
                .finally(() => setBusy(false));
            }}
          >
            <StaffLanguage
              locale={locale}
              onChange={setLocale}
              disabled={busy || uncertain}
            />
            <p>
              {t(
                "Language changes this staff account experience. It grants no additional access.",
                "La langue modifie l’affichage de cet espace de compte du personnel. Elle ne donne aucun accès supplémentaire.",
              )}
              {saved.navigation?.classroom === true &&
                t(
                  " Classroom pages are currently in English.",
                  " Les pages des classes sont actuellement en anglais.",
                )}
            </p>
            <div className="c-staff__actions">
              <ActionButton type="submit" disabled={busy || uncertain}>
                {t("Save preferences", "Enregistrer les préférences")}
              </ActionButton>
              <ActionButton
                variant="secondary"
                disabled={busy}
                onClick={() => void load()}
              >
                {t("Reload preferences", "Recharger les préférences")}
              </ActionButton>
            </div>
          </form>
        </Panel>
      ) : (
        !busy && <StaffBlocked locale={locale} />
      )}
    </StaffFrame>
  );
}
