import type { ReactNode } from "react";

export type StatusTone =
  "neutral" | "information" | "positive" | "attention" | "critical";

type StatusBadgeProps = Readonly<{
  children: ReactNode;
  tone?: StatusTone;
}>;

const toneClasses: Record<StatusTone, string> = {
  neutral: "",
  information: " c-status--information",
  positive: " c-status--positive",
  attention: " c-status--attention",
  critical: " c-status--critical",
};

export function StatusBadge({ children, tone = "neutral" }: StatusBadgeProps) {
  return <span className={`c-status${toneClasses[tone]}`}>{children}</span>;
}
