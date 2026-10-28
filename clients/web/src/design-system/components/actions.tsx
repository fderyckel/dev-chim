import type { MouseEventHandler, ReactNode } from "react";
import Link from "next/link";

type ActionVariant = "primary" | "secondary" | "quiet";
type ActionIcon = "back" | "down" | "forward";

const icons: Record<ActionIcon, string> = {
  back: "←",
  down: "↓",
  forward: "→",
};

type ActionContentProps = Readonly<{
  children: ReactNode;
  icon?: ActionIcon;
  iconPosition?: "before" | "after";
}>;

function ActionContent({ children, icon, iconPosition = "after" }: ActionContentProps) {
  const iconElement = icon ? (
    <span className="c-button__icon" aria-hidden="true">
      {icons[icon]}
    </span>
  ) : null;

  return (
    <>
      {iconPosition === "before" ? iconElement : null}
      {children}
      {iconPosition === "after" ? iconElement : null}
    </>
  );
}

type ActionLinkProps = ActionContentProps &
  Readonly<{
    href: string;
    reloadDocument?: boolean;
    variant?: ActionVariant;
  }>;

export function ActionLink({
  children,
  href,
  reloadDocument = false,
  icon,
  iconPosition,
  variant = "primary",
}: ActionLinkProps) {
  const className = `c-button c-button--${variant}`;
  const content = (
    <ActionContent icon={icon} iconPosition={iconPosition}>
      {children}
    </ActionContent>
  );

  return href.startsWith("#") || reloadDocument ? (
    <a className={className} href={href}>
      {content}
    </a>
  ) : (
    <Link className={className} href={href}>
      {content}
    </Link>
  );
}

type ActionButtonProps = ActionContentProps &
  Readonly<{
    id?: string;
    ariaLabel?: string;
    ariaExpanded?: boolean;
    ariaControls?: string;
    ariaDescribedBy?: string;
    disabled?: boolean;
    onClick?: MouseEventHandler<HTMLButtonElement>;
    type?: "button" | "submit";
    variant?: ActionVariant;
  }>;

export function ActionButton({
  id,
  ariaLabel,
  ariaExpanded,
  ariaControls,
  ariaDescribedBy,
  children,
  disabled = false,
  icon,
  iconPosition,
  onClick,
  type = "button",
  variant = "primary",
}: ActionButtonProps) {
  return (
    <button
      id={id}
      aria-label={ariaLabel}
      aria-expanded={ariaExpanded}
      aria-controls={ariaControls}
      aria-describedby={ariaDescribedBy}
      className={`c-button c-button--${variant}`}
      disabled={disabled}
      onClick={onClick}
      type={type}
    >
      <ActionContent icon={icon} iconPosition={iconPosition}>
        {children}
      </ActionContent>
    </button>
  );
}
