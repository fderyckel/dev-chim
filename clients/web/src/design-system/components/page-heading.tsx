import type { ReactNode } from "react";

type PageHeadingProps = Readonly<{
  aside?: ReactNode;
  description: ReactNode;
  eyebrow: ReactNode;
  title: ReactNode;
}>;

export function PageHeading({ aside, description, eyebrow, title }: PageHeadingProps) {
  return (
    <header className="c-page-heading">
      <div className="c-page-heading__copy">
        <p className="c-page-heading__eyebrow">{eyebrow}</p>
        <h1 className="c-page-heading__title">{title}</h1>
        <p className="c-page-heading__lede">{description}</p>
      </div>
      {aside ? <div className="c-page-heading__assurance">{aside}</div> : null}
    </header>
  );
}
