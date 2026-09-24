import "@testing-library/jest-dom/vitest";

import { createElement, type AnchorHTMLAttributes } from "react";
import { vi } from "vitest";

type LinkProps = AnchorHTMLAttributes<HTMLAnchorElement> & {
  href: string;
};

vi.mock("next/link", () => ({
  default: function MockNextLink({ href, ...props }: LinkProps) {
    return createElement("a", { ...props, href });
  },
}));
