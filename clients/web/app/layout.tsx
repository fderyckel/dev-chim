import type { Metadata } from "next";

import "../src/styles/index.css";

export const metadata: Metadata = {
  title: {
    default: "Chimwemwe local prototype",
    template: "%s · Chimwemwe local prototype",
  },
  description:
    "A local, synthetic browser prototype for evaluating the Chimwemwe experience foundation.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="l-app-document">{children}</body>
    </html>
  );
}
