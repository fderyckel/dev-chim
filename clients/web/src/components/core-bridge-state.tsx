import type { CoreBridgeFailure } from "../ports/core-bridge";

type CoreBridgeStateProps = Readonly<{
  result: CoreBridgeFailure;
}>;

const copy = {
  disabled: {
    title: "The local core bridge is not enabled",
    description: "This page only opens through the guarded local UI-1A command.",
    recovery: "Start the local connected experience, then reload this page.",
  },
  denied: {
    title: "This local session cannot open assignment options",
    description: "Restricted details were not returned to the browser.",
    recovery: "Restart the local connected experience to establish a new session.",
  },
  retryable: {
    title: "The local core is temporarily unavailable",
    description: "No change was attempted and no private detail was returned.",
    recovery: "Wait a moment, then reload this page once.",
  },
  unavailable: {
    title: "The browser experience cannot reach the local core",
    description: "The read-only connection is unavailable. Nothing was changed.",
    recovery:
      "Check that the local connected experience is still running, then reload.",
  },
  unexpected: {
    title: "The local core request could not be completed",
    description: "The response did not match the checked UI-1A contract.",
    recovery: "Return to Home or restart the local connected experience.",
  },
} as const;

export function CoreBridgeStateView({ result }: CoreBridgeStateProps) {
  const stateCopy = copy[result.state];

  return (
    <div className="l-page-stack">
      <header className="c-page-heading">
        <div className="c-page-heading__copy">
          <p className="c-page-heading__eyebrow">Authority preparation</p>
          <h1 className="c-page-heading__title">Prepare a role assignment</h1>
          <p className="c-page-heading__lede">
            A local, read-only core connection is required for this qualification view.
          </p>
        </div>
      </header>

      <section className="c-bridge-state" role="status">
        <span className="c-bridge-state__symbol" aria-hidden="true">
          !
        </span>
        <div className="c-bridge-state__body">
          <p className="c-bridge-state__label">Connection unavailable</p>
          <h2 className="c-bridge-state__title">{stateCopy.title}</h2>
          <p className="c-bridge-state__description">{stateCopy.description}</p>
          <p className="c-bridge-state__recovery">
            <strong>What to do:</strong> {stateCopy.recovery}
          </p>
          {result.reference ? (
            <p className="c-bridge-state__reference">
              Support reference: {result.reference}
            </p>
          ) : null}
        </div>
      </section>
    </div>
  );
}
