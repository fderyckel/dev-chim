"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { ActionButton, ActionLink } from "../design-system/components/actions";
import { Panel } from "../design-system/components/panel";
import { StatusBadge } from "../design-system/components/status-badge";
import {
  StaffBlocked,
  StaffFrame,
  StaffHelp,
  StaffLanguage,
  StaffRequestError,
  actionReferences,
  staffActionMessage,
  staffLocale,
  staffRequest,
  staffSession,
  translate,
  type StaffAccount,
  type StaffActionInput,
  type StaffInventory,
  type StaffLocale,
  type StaffPreference,
  type StaffReceipt,
} from "./staff-shared";

type Details = {
  given_name: string;
  family_name: string;
  display_name: string;
  locale: StaffLocale;
};
const emptyDetails: Details = {
  given_name: "",
  family_name: "",
  display_name: "",
  locale: "en",
};
type ActionPath =
  | "/api/v1/staff-accounts/provision"
  | "/api/v1/staff-accounts/revise-details"
  | "/api/v1/staff-accounts/set-access"
  | "/api/v1/staff-accounts/revoke-access-profile"
  | "/api/v1/staff-accounts/suspend-access"
  | "/api/v1/staff-accounts/reissue";

function detailValues(account: StaffAccount): Details {
  return {
    given_name: account.given_name ?? "",
    family_name: account.family_name ?? "",
    display_name: account.display_name,
    locale: staffLocale(account.locale),
  };
}

function DetailsFields({
  values,
  setValues,
  locale,
  disabled,
}: {
  values: Details;
  setValues: (values: Details) => void;
  locale: StaffLocale;
  disabled: boolean;
}) {
  const t = translate(locale);
  return (
    <>
      <div className="c-staff__field-pair">
        <label>
          {t("First name (optional)", "Prénom (facultatif)")}
          <input
            value={values.given_name}
            onChange={(event) =>
              setValues({ ...values, given_name: event.target.value })
            }
            autoComplete="given-name"
            maxLength={120}
            disabled={disabled}
          />
        </label>
        <label>
          {t("Last name (optional)", "Nom de famille (facultatif)")}
          <input
            value={values.family_name}
            onChange={(event) =>
              setValues({ ...values, family_name: event.target.value })
            }
            autoComplete="family-name"
            maxLength={120}
            disabled={disabled}
          />
        </label>
      </div>
      <label>
        {t("Display name", "Nom affiché")}
        <input
          value={values.display_name}
          onChange={(event) =>
            setValues({ ...values, display_name: event.target.value })
          }
          autoComplete="name"
          required
          maxLength={240}
          disabled={disabled}
        />
      </label>
      <StaffLanguage
        locale={values.locale}
        displayLocale={locale}
        onChange={(next) => setValues({ ...values, locale: next })}
        disabled={disabled}
      />
    </>
  );
}

function AccountStatus({
  account,
  locale,
}: {
  account: StaffAccount;
  locale: StaffLocale;
}) {
  const t = translate(locale);
  const expired =
    !!account.temporary_password_expires_at &&
    new Date(account.temporary_password_expires_at) < new Date();
  return (
    <div className="c-staff__statuses">
      <StatusBadge tone={account.status === "active" ? "positive" : "attention"}>
        {account.status === "active"
          ? t("Active sign-in", "Connexion active")
          : account.status === "suspended"
            ? t("Sign-in suspended", "Connexion suspendue")
            : expired
              ? t("Temporary password expired", "Mot de passe temporaire expiré")
              : t("First login required", "Première connexion requise")}
      </StatusBadge>
      <StatusBadge
        tone={account.source_current && account.enabled ? "information" : "critical"}
      >
        {!account.source_current
          ? t(
              "Staff association no longer current",
              "Association du personnel non actuelle",
            )
          : account.enabled
            ? t("Institution access enabled", "Accès à l’établissement activé")
            : t("Institution access suspended", "Accès à l’établissement suspendu")}
      </StatusBadge>
    </div>
  );
}

export function StaffDirectory({ accountId }: { accountId?: string }) {
  // A new account must not inherit the previous route's loaded editing state.
  return <StaffDirectoryPage key={accountId ?? "inventory"} accountId={accountId} />;
}

function StaffDirectoryPage({ accountId }: { accountId?: string }) {
  const [locale, setLocale] = useState<StaffLocale>("en");
  const [inventory, setInventory] = useState<StaffInventory | null>(null);
  const [presentation, setPresentation] = useState<StaffPreference | null>(null);
  const [csrf, setCsrf] = useState<string | null>(null);
  const [actorId, setActorId] = useState<string | null>(null);
  const [busy, setBusy] = useState(true);
  const [uncertain, setUncertain] = useState(false);
  const [message, setMessage] = useState("");
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState("");
  const [email, setEmail] = useState("");
  const [details, setDetails] = useState<Details>(emptyDetails);
  const [identityConfirmed, setIdentityConfirmed] = useState(false);
  const [securityConfirmed, setSecurityConfirmed] = useState(false);
  const [suspendConfirmed, setSuspendConfirmed] = useState(false);
  const [profileId, setProfileId] = useState("");
  const [secret, setSecret] = useState<{
    password: string;
    name: string;
    email: string;
    expires?: string | null;
  } | null>(null);
  const [copied, setCopied] = useState(false);
  const secretHeading = useRef<HTMLSpanElement>(null);
  const createStaffSelect = useRef<HTMLSelectElement>(null);
  const requestGeneration = useRef(0);
  const departed = useRef(false);
  const t = translate(locale);
  const account = inventory?.accounts.find((item) => item.id === accountId);
  const candidate = inventory?.eligible_staff.find(
    (item) => item.association_id === selected,
  );

  async function load(success?: string, generation = ++requestGeneration.current) {
    const currentLoad = () =>
      !departed.current && generation === requestGeneration.current;
    if (!currentLoad()) return false;
    setBusy(true);
    setPresentation(null);
    let authenticated = false;
    try {
      const session = await staffSession();
      if (!currentLoad()) return false;
      authenticated = true;
      setCsrf(session.csrf_token);
      const currentPresentation = await staffRequest<StaffPreference>(
        "/api/v1/staff-preferences",
      );
      if (!currentLoad()) return false;
      const loaded = await staffRequest<StaffInventory>("/api/v1/staff-accounts");
      if (!currentLoad()) return false;
      setActorId(session.actor_id);
      setPresentation(currentPresentation);
      setInventory(loaded);
      setLocale(staffLocale(loaded.locale));
      const current = loaded.accounts.find((item) => item.id === accountId);
      if (current) {
        setDetails(detailValues(current));
        setSecurityConfirmed(false);
        setSuspendConfirmed(false);
        setProfileId(
          current.roles.find((role) =>
            loaded.profiles.some((profile) => profile.id === role.id),
          )?.id ?? "",
        );
      }
      setUncertain(false);
      setMessage(
        success ??
          translate(staffLocale(loaded.locale))(
            "Current account status loaded.",
            "État actuel des comptes chargé.",
          ),
      );
    } catch (error) {
      if (!currentLoad()) return false;
      setInventory(null);
      if (
        !authenticated ||
        (error instanceof StaffRequestError && error.status === 401)
      )
        setCsrf(null);
      setActorId(null);
      setPresentation(null);
      setSecret(null);
      setMessage(staffActionMessage(error, locale));
      return false;
    } finally {
      if (currentLoad()) setBusy(false);
    }
  }

  useEffect(() => {
    departed.current = false;
    const arrival = ++requestGeneration.current;
    void Promise.resolve().then(() => {
      if (!departed.current && arrival === requestGeneration.current) return load();
    });
    return () => {
      departed.current = true;
      requestGeneration.current += 1;
    };
    // Each route arrival gets a fresh writer-authorized inventory; no browser cache.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [accountId]);

  useEffect(() => {
    const clearSecret = () => {
      departed.current = true;
      requestGeneration.current += 1;
      setSecret(null);
      setPresentation(null);
      setInventory(null);
      setCsrf(null);
      setActorId(null);
    };
    window.addEventListener("pagehide", clearSecret);
    return () => window.removeEventListener("pagehide", clearSecret);
  }, []);
  useEffect(() => {
    if (secret) {
      secretHeading.current?.focus({ preventScroll: true });
      secretHeading.current
        ?.closest("section")
        ?.scrollIntoView({ block: "start", behavior: "instant" });
    }
  }, [secret]);

  async function mutate(
    path: ActionPath,
    body: StaffActionInput,
    success: string,
    identity?: { name: string; email: string },
  ) {
    if (!csrf || departed.current) return;
    const generation = ++requestGeneration.current;
    const currentRequest = () =>
      !departed.current && generation === requestGeneration.current;
    setBusy(true);
    setSecret(null);
    setCopied(false);
    try {
      const result = await staffRequest<StaffReceipt>(
        path,
        { ...body, ...actionReferences() },
        csrf,
      );
      if (!currentRequest()) return;
      const confirmed = await load(success, generation);
      if (confirmed === false || !currentRequest()) return;
      if (result.temporary_password && identity)
        setSecret({
          password: result.temporary_password,
          ...identity,
          expires: result.temporary_password_expires_at,
        });
      else if (
        (path.endsWith("/provision") || path.endsWith("/reissue")) &&
        !result.temporary_password
      )
        setMessage(
          t(
            "The action is recorded. Its temporary password cannot be displayed again. Check the account before issuing a new one.",
            "L’action est enregistrée. Son mot de passe temporaire ne peut pas être réaffiché. Vérifiez le compte avant d’en générer un nouveau.",
          ),
        );
      setIdentityConfirmed(false);
      setSecurityConfirmed(false);
      setSuspendConfirmed(false);
      if (path.endsWith("/provision")) {
        setSelected("");
        setEmail("");
        setDetails(emptyDetails);
      }
    } catch (error) {
      if (!currentRequest()) return;
      setMessage(staffActionMessage(error, locale));
      setUncertain(true);
      if (
        error instanceof StaffRequestError &&
        (error.status === 401 || error.status === 403)
      ) {
        setInventory(null);
        if (error.status === 401) setCsrf(null);
      }
    } finally {
      if (currentRequest()) setBusy(false);
    }
  }

  function provision(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!candidate || !identityConfirmed) return;
    void mutate(
      "/api/v1/staff-accounts/provision",
      {
        association_id: candidate.association_id,
        ...details,
        given_name: details.given_name || null,
        family_name: details.family_name || null,
        email,
      },
      t(
        "Staff account created. Set its access separately.",
        "Compte du personnel créé. Définissez son accès séparément.",
      ),
      { name: details.display_name, email },
    );
  }

  const disabled = busy || uncertain || (account ? !account.source_current : false);
  const visibleAccounts =
    inventory?.accounts.filter((item) =>
      `${item.display_name} ${item.email}`
        .toLocaleLowerCase()
        .includes(query.toLocaleLowerCase()),
    ) ?? [];
  return (
    <StaffFrame
      locale={locale}
      title={
        accountId
          ? (account?.display_name ?? t("Staff account", "Compte du personnel"))
          : t("Accounts", "Comptes")
      }
      description={t(
        "Manage staff sign-in and institutional access separately.",
        "Gérez séparément la connexion du personnel et l’accès à l’établissement.",
      )}
      institution={inventory?.institution_label}
      csrf={csrf}
      presentation={presentation}
      onSignedOut={() => {
        departed.current = true;
        requestGeneration.current += 1;
        setSecret(null);
        setInventory(null);
        setCsrf(null);
        setPresentation(null);
      }}
    >
      <p
        className="c-staff__message"
        role="status"
        aria-live="polite"
        id="staff-directory-status"
      >
        {message || t("Checking your access…", "Vérification de votre accès…")}
      </p>
      {csrf && (
        <div className="c-staff__actions">
          {!accountId && inventory && (
            <ActionButton
              disabled={disabled || !inventory.eligible_staff.length}
              onClick={() => {
                createStaffSelect.current?.focus();
              }}
            >
              {t("New staff account", "Nouveau compte du personnel")}
            </ActionButton>
          )}
          <ActionButton
            variant="secondary"
            disabled={busy}
            onClick={() => {
              setSecret(null);
              void load();
            }}
          >
            {t("Reload status", "Recharger l’état")}
          </ActionButton>
          {accountId && (
            <ActionLink
              href="/accounts"
              variant="quiet"
              icon="back"
              iconPosition="before"
            >
              {t("All accounts", "Tous les comptes")}
            </ActionLink>
          )}
        </div>
      )}
      {!inventory ? (
        !busy && <StaffBlocked locale={locale} />
      ) : (
        <>
          {secret && (
            <Panel
              eyebrow={t("Security", "Sécurité")}
              title={
                <span ref={secretHeading} tabIndex={-1}>
                  {t("Temporary password generated", "Mot de passe temporaire généré")}
                </span>
              }
              titleId="temporary-password-title"
              tone="attention"
            >
              <div className="c-staff__form">
                <p>
                  <strong>{secret.name}</strong>
                  <br />
                  {secret.email}
                </p>
                <p>
                  {t(
                    "Shown once. Deliver privately after verifying the recipient’s identity.",
                    "Affiché une seule fois. Transmettez-le de manière privée après avoir vérifié l’identité du destinataire.",
                  )}
                </p>
                <code className="c-staff__secret" data-testid="temporary-password">
                  {secret.password}
                </code>
                {secret.expires && (
                  <p>
                    {t("Expires: ", "Expiration : ")}
                    <time dateTime={secret.expires}>
                      {new Date(secret.expires).toLocaleString(locale)}
                    </time>
                  </p>
                )}
                <div className="c-staff__actions">
                  <ActionButton
                    variant="secondary"
                    onClick={() => {
                      void navigator.clipboard
                        .writeText(secret.password)
                        .then(() => setCopied(true))
                        .catch(() => setCopied(false));
                    }}
                  >
                    {copied
                      ? t("Copied", "Copié")
                      : t(
                          "Copy temporary password",
                          "Copier le mot de passe temporaire",
                        )}
                  </ActionButton>
                  <ActionButton variant="quiet" onClick={() => setSecret(null)}>
                    {t(
                      "Dismiss temporary password",
                      "Fermer le mot de passe temporaire",
                    )}
                  </ActionButton>
                </div>
                <p>
                  {t(
                    "After you dismiss this password, leave or reload, it cannot be displayed again. Generated does not mean delivered.",
                    "Après avoir fermé ce mot de passe, quitté la page ou rechargé, vous ne pourrez plus le consulter. Sa génération ne signifie pas qu’il a été transmis.",
                  )}
                </p>
              </div>
            </Panel>
          )}
          {!accountId ? (
            <>
              <Panel
                eyebrow={inventory.institution_label}
                title={t("Staff accounts", "Comptes du personnel")}
                titleId="staff-accounts-title"
              >
                <div className="c-staff__form">
                  <label>
                    {t("Find an account", "Rechercher un compte")}
                    <input
                      type="search"
                      value={query}
                      onChange={(event) => setQuery(event.target.value)}
                      autoComplete="off"
                    />
                  </label>
                  <ul
                    className="c-staff__account-list"
                    aria-label={t("Staff accounts", "Comptes du personnel")}
                  >
                    {visibleAccounts.map((item) => (
                      <li key={item.id}>
                        <div>
                          <a
                            href={`/accounts/${item.id}`}
                            className="c-staff__account-name"
                          >
                            {item.display_name}
                          </a>
                          <p>
                            {t("Sign-in email: ", "Adresse de connexion : ")}
                            {item.email}
                          </p>
                          <p>
                            {t("Staff reference: ", "Référence du personnel : ")}
                            {item.association_id.slice(0, 8)}
                          </p>
                          <p>
                            {t("Access: ", "Accès : ")}
                            {item.roles.map((role) => role.label).join(", ") ||
                              t("No role assigned", "Aucun rôle attribué")}
                            {" · "}
                            {inventory.institution_label}
                          </p>
                        </div>
                        <AccountStatus account={item} locale={locale} />
                      </li>
                    ))}
                  </ul>
                  {!visibleAccounts.length && (
                    <p>{t("No matching accounts.", "Aucun compte correspondant.")}</p>
                  )}
                </div>
              </Panel>
              <Panel
                eyebrow={t(
                  "Existing verified staff only",
                  "Personnel existant vérifié uniquement",
                )}
                title={t("Create staff account", "Créer un compte du personnel")}
                titleId="staff-create-title"
                id="staff-create"
              >
                <form
                  className="c-staff__form"
                  onSubmit={provision}
                  aria-describedby="staff-directory-status"
                >
                  <label>
                    {t("Staff member", "Membre du personnel")}
                    <select
                      ref={createStaffSelect}
                      value={selected}
                      required
                      disabled={disabled || !inventory.eligible_staff.length}
                      onChange={(event) => {
                        const person = inventory.eligible_staff.find(
                          (item) => item.association_id === event.target.value,
                        );
                        setSelected(event.target.value);
                        setDetails({
                          ...emptyDetails,
                          display_name: person?.display_name ?? "",
                          locale,
                        });
                        setIdentityConfirmed(false);
                      }}
                    >
                      <option value="">
                        {t(
                          "Choose a verified staff record",
                          "Choisir un membre du personnel vérifié",
                        )}
                      </option>
                      {inventory.eligible_staff.map((item) => (
                        <option key={item.association_id} value={item.association_id}>
                          {item.display_name} · {item.association_id.slice(0, 8)}
                        </option>
                      ))}
                    </select>
                  </label>
                  {!inventory.eligible_staff.length && (
                    <p>
                      {t(
                        "No eligible staff are waiting for an account.",
                        "Aucun membre du personnel éligible n’attend de compte.",
                      )}
                    </p>
                  )}
                  {candidate && (
                    <>
                      <p className="c-staff__identity">
                        <strong>{candidate.display_name}</strong>
                        <br />
                        {inventory.institution_label}
                        <br />
                        {t("Staff reference: ", "Référence du personnel : ")}
                        {candidate.association_id.slice(0, 8)}
                      </p>
                      <DetailsFields
                        values={details}
                        setValues={setDetails}
                        locale={locale}
                        disabled={disabled}
                      />
                      <label>
                        {t("Sign-in email", "Adresse e-mail de connexion")}
                        <input
                          type="email"
                          value={email}
                          onChange={(event) => {
                            setEmail(event.target.value);
                            setIdentityConfirmed(false);
                          }}
                          required
                          autoComplete="off"
                          autoCapitalize="none"
                          spellCheck={false}
                          disabled={disabled}
                        />
                      </label>
                      <label className="c-staff__check">
                        <input
                          type="checkbox"
                          checked={identityConfirmed}
                          onChange={(event) =>
                            setIdentityConfirmed(event.target.checked)
                          }
                          required
                          disabled={disabled}
                        />
                        {t(
                          "I checked this staff identity and sign-in email.",
                          "J’ai vérifié l’identité de ce membre du personnel et son adresse de connexion.",
                        )}
                      </label>
                      <p>
                        {t(
                          "Creates sign-in credentials only. Access is a separate action.",
                          "Crée uniquement les identifiants de connexion. L’accès fait l’objet d’une action distincte.",
                        )}
                      </p>
                      <div className="c-staff__actions">
                        <ActionButton
                          type="submit"
                          disabled={disabled || !identityConfirmed}
                        >
                          {t("Create staff account", "Créer un compte du personnel")}
                        </ActionButton>
                        <ActionButton
                          variant="quiet"
                          disabled={busy}
                          onClick={() => {
                            setSelected("");
                            setEmail("");
                            setDetails(emptyDetails);
                            setIdentityConfirmed(false);
                          }}
                        >
                          {t("Cancel", "Annuler")}
                        </ActionButton>
                      </div>
                    </>
                  )}
                </form>
              </Panel>
            </>
          ) : account ? (
            <>
              <AccountStatus account={account} locale={locale} />
              {!account.source_current && (
                <p className="c-staff__message">
                  {t(
                    "Account changes are unavailable while the staff affiliation is not current. Contact the institution’s staff-record administrator.",
                    "Les modifications du compte sont indisponibles tant que l’affiliation au personnel n’est pas actuelle. Contactez la personne responsable des dossiers du personnel de l’établissement.",
                  )}
                </p>
              )}
              <div className="c-staff__identity">
                <p>
                  {t("Sign-in email: ", "Adresse de connexion : ")}
                  {account.email}
                </p>
                <p>
                  {t("Staff reference: ", "Référence du personnel : ")}
                  {account.association_id.slice(0, 8)} · {inventory.institution_label}
                </p>
              </div>
              <nav
                className="c-staff__actions"
                aria-label={t("Account sections", "Sections du compte")}
              >
                <ActionLink href="#staff-details" variant="secondary">
                  {t("Details", "Informations")}
                </ActionLink>
                <ActionLink href="#staff-access" variant="secondary">
                  {t("Access", "Accès")}
                </ActionLink>
                <ActionLink href="#staff-security" variant="secondary">
                  {t("Security", "Sécurité")}
                </ActionLink>
              </nav>
              <Panel
                id="staff-details"
                eyebrow={t("Profile", "Profil")}
                title={t("Details", "Informations")}
                titleId="staff-details-title"
              >
                <form
                  className="c-staff__form"
                  onSubmit={(event) => {
                    event.preventDefault();
                    void mutate(
                      "/api/v1/staff-accounts/revise-details",
                      {
                        id: account.id,
                        expected_version: account.lock_version,
                        ...details,
                        given_name: details.given_name || null,
                        family_name: details.family_name || null,
                      },
                      t(
                        "Details saved. Access is unchanged.",
                        "Informations enregistrées. L’accès est inchangé.",
                      ),
                    );
                  }}
                >
                  <DetailsFields
                    values={details}
                    setValues={setDetails}
                    locale={locale}
                    disabled={disabled}
                  />
                  <p>
                    {t(
                      "Sign-in email is fixed in this evaluation. Contact your account administrator if it is incorrect.",
                      "L’adresse de connexion est fixe dans cette évaluation. Contactez l’administrateur de votre compte si elle est incorrecte.",
                    )}
                  </p>
                  <div className="c-staff__actions">
                    <ActionButton type="submit" disabled={disabled}>
                      {t("Save details", "Enregistrer les informations")}
                    </ActionButton>
                    <StaffHelp
                      id="staff-name-help"
                      label={t("About names", "À propos des noms")}
                    >
                      {t(
                        "Use the staff member’s chosen display name. First and last names are optional and never used to merge identities.",
                        "Utilisez le nom d’affichage choisi par le membre du personnel. Le prénom et le nom sont facultatifs et ne servent jamais à fusionner des identités.",
                      )}
                    </StaffHelp>
                  </div>
                </form>
              </Panel>
              <Panel
                id="staff-access"
                eyebrow={inventory.institution_label}
                title={t("Access", "Accès")}
                titleId="staff-access-title"
              >
                <div className="c-staff__form">
                  <p>
                    {t("Current roles: ", "Rôles actuels : ")}
                    {account.roles.map((role) => role.label).join(", ") ||
                      t("None", "Aucun")}
                  </p>
                  <form
                    className="c-staff__form-section"
                    onSubmit={(event) => {
                      event.preventDefault();
                      void mutate(
                        "/api/v1/staff-accounts/set-access",
                        {
                          id: account.id,
                          expected_version: account.lock_version,
                          profile_id: profileId,
                        },
                        t("Access profile added.", "Profil d’accès ajouté."),
                      );
                    }}
                  >
                    <label>
                      {t("Access profile", "Profil d’accès")}
                      <select
                        value={profileId}
                        onChange={(event) => setProfileId(event.target.value)}
                        disabled={disabled}
                      >
                        <option value="">
                          {t(
                            "Choose a permitted access profile",
                            "Choisir un profil d’accès autorisé",
                          )}
                        </option>
                        {inventory.profiles.map((profile) => (
                          <option key={profile.id} value={profile.id}>
                            {profile.label}
                          </option>
                        ))}
                      </select>
                    </label>
                    <p>
                      {t(
                        "Add or remove this role in this institution. Other roles remain separate. Classroom assignments are checked separately.",
                        "Ajoutez ou retirez ce rôle dans cet établissement. Les autres rôles restent distincts. Les affectations aux classes sont vérifiées séparément.",
                      )}
                    </p>
                    <div className="c-staff__actions">
                      <ActionButton
                        type="submit"
                        disabled={
                          disabled ||
                          !profileId ||
                          account.roles.some((role) => role.id === profileId)
                        }
                      >
                        {t("Add access profile", "Ajouter le profil d’accès")}
                      </ActionButton>
                      <ActionButton
                        variant="secondary"
                        disabled={
                          disabled ||
                          !profileId ||
                          !account.roles.some((role) => role.id === profileId)
                        }
                        onClick={() =>
                          void mutate(
                            "/api/v1/staff-accounts/revoke-access-profile",
                            {
                              id: account.id,
                              expected_version: account.lock_version,
                              profile_id: profileId,
                            },
                            t(
                              "Access profile removed. Other roles are unchanged.",
                              "Profil d’accès retiré. Les autres rôles sont inchangés.",
                            ),
                          )
                        }
                      >
                        {t("Remove selected profile", "Retirer le profil sélectionné")}
                      </ActionButton>
                      <StaffHelp
                        id="staff-access-help"
                        label={t(
                          "About access profiles",
                          "À propos des profils d’accès",
                        )}
                      >
                        {t(
                          "A profile selects an existing institution-defined role. Language and display preferences grant no access. Administrative privileges cannot be granted here.",
                          "Un profil sélectionne un rôle existant défini par l’établissement. La langue et les préférences d’affichage ne donnent aucun accès. Aucun privilège administratif ne peut être accordé ici.",
                        )}
                      </StaffHelp>
                    </div>
                  </form>
                  <form
                    className="c-staff__form-section"
                    onSubmit={(event) => {
                      event.preventDefault();
                      if (suspendConfirmed)
                        void mutate(
                          "/api/v1/staff-accounts/suspend-access",
                          { id: account.id, expected_version: account.lock_version },
                          t(
                            "Institution access suspended. Current sessions can no longer use this institution.",
                            "Accès à l’établissement suspendu. Les sessions actuelles ne peuvent plus utiliser cet établissement.",
                          ),
                        );
                    }}
                  >
                    <h3>
                      {t(
                        "Suspend access to this institution",
                        "Suspendre l’accès à cet établissement",
                      )}
                    </h3>
                    <p>
                      {t(
                        "Ends this institution’s access, including current sessions. Institutional records remain. It does not suspend sign-in everywhere.",
                        "Met fin à l’accès à cet établissement, y compris les sessions actuelles. Les dossiers sont conservés. La connexion n’est pas suspendue partout.",
                      )}
                    </p>
                    <label className="c-staff__check">
                      <input
                        type="checkbox"
                        checked={suspendConfirmed}
                        onChange={(event) => setSuspendConfirmed(event.target.checked)}
                        disabled={disabled || !account.enabled}
                      />
                      {t(
                        "I confirm the institution and staff member above.",
                        "Je confirme l’établissement et le membre du personnel indiqués ci-dessus.",
                      )}
                    </label>
                    <div>
                      <ActionButton
                        type="submit"
                        variant="secondary"
                        disabled={disabled || !suspendConfirmed || !account.enabled}
                      >
                        {t(
                          "Suspend institution access",
                          "Suspendre l’accès à l’établissement",
                        )}
                      </ActionButton>
                    </div>
                  </form>
                </div>
              </Panel>
              <Panel
                id="staff-security"
                eyebrow={t("Credentials", "Identifiants")}
                title={t("Security", "Sécurité")}
                titleId="staff-security-title"
              >
                <form
                  className="c-staff__form"
                  onSubmit={(event) => {
                    event.preventDefault();
                    if (securityConfirmed)
                      void mutate(
                        "/api/v1/staff-accounts/reissue",
                        { id: account.id, expected_version: account.lock_version },
                        t(
                          "New temporary password generated. The earlier credential is invalid.",
                          "Nouveau mot de passe temporaire généré. Le mot de passe précédent est invalide.",
                        ),
                        { name: account.display_name, email: account.email },
                      );
                  }}
                >
                  <p>
                    {t(
                      "Existing passwords cannot be viewed. A new temporary password replaces the current credential and ends current sign-in sessions.",
                      "Les mots de passe existants ne peuvent pas être consultés. Un nouveau mot de passe temporaire remplace le mot de passe précédent et met fin aux sessions de connexion en cours.",
                    )}
                  </p>
                  {account.actor_id === actorId && (
                    <p>
                      {t(
                        "Your own password cannot be reissued here. Contact your institution’s account administrator.",
                        "Vous ne pouvez pas renouveler votre propre mot de passe ici. Contactez l’administrateur des comptes de votre établissement.",
                      )}
                    </p>
                  )}
                  <p>
                    {t(
                      "The recipient must choose a new password at the next sign-in. This action does not restore suspended institution access.",
                      "Le destinataire doit choisir un nouveau mot de passe à sa prochaine connexion. Cette action ne rétablit pas un accès suspendu à l’établissement.",
                    )}
                  </p>
                  <label className="c-staff__check">
                    <input
                      type="checkbox"
                      checked={securityConfirmed}
                      onChange={(event) => setSecurityConfirmed(event.target.checked)}
                      disabled={disabled || account.actor_id === actorId}
                    />
                    {t(
                      "I verified the recipient and can deliver the password privately.",
                      "J’ai vérifié le destinataire et peux transmettre le mot de passe de manière privée.",
                    )}
                  </label>
                  <div>
                    <ActionButton
                      type="submit"
                      variant="secondary"
                      disabled={
                        disabled || !securityConfirmed || account.actor_id === actorId
                      }
                    >
                      {t("New temporary password", "Nouveau mot de passe temporaire")}
                    </ActionButton>
                  </div>
                </form>
              </Panel>
            </>
          ) : (
            <p>
              {t(
                "This account is unavailable in your current institution.",
                "Ce compte n’est pas disponible dans votre établissement actuel.",
              )}
            </p>
          )}
        </>
      )}
    </StaffFrame>
  );
}
