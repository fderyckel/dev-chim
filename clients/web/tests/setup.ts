import "@testing-library/jest-dom/vitest";

import { createElement, type AnchorHTMLAttributes } from "react";
import { vi } from "vitest";

// jsdom has no native modal-dialog API; browser suites verify focus containment.
if (typeof HTMLDialogElement !== "undefined") {
  Object.defineProperty(HTMLDialogElement.prototype, "showModal", {
    configurable: true,
    value: function (this: HTMLDialogElement) {
      this.setAttribute("open", "");
    },
  });
}

type LinkProps = AnchorHTMLAttributes<HTMLAnchorElement> & {
  href: string;
};

vi.mock("next/link", () => ({
  default: function MockNextLink({ href, ...props }: LinkProps) {
    return createElement("a", { ...props, href });
  },
}));
