import type { ReactNode } from "react";

type PanelProps = Readonly<{
  badge?: ReactNode;
  children: ReactNode;
  description?: ReactNode;
  eyebrow: ReactNode;
  footer?: ReactNode;
  id?: string;
  title: ReactNode;
  titleId: string;
  tone?: "neutral" | "attention";
}>;

export function Panel({
  badge,
  children,
  description,
  eyebrow,
  footer,
  id,
  title,
  titleId,
  tone = "neutral",
}: PanelProps) {
  const toneClass = tone === "attention" ? " c-panel--attention" : "";

  return (
    <section className={`c-panel${toneClass}`} id={id} aria-labelledby={titleId}>
      <header className="c-panel__header">
        <div className="c-panel__heading-group">
          <p className="c-panel__eyebrow">{eyebrow}</p>
          <h2 className="c-panel__title" id={titleId}>
            {title}
          </h2>
          {description ? <p className="c-panel__description">{description}</p> : null}
        </div>
        {badge}
      </header>
      {children}
      {footer ? <footer className="c-panel__footnote">{footer}</footer> : null}
    </section>
  );
}
