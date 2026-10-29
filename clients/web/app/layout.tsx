import type { Metadata } from "next";
import { connection } from "next/server";
import { DemoLayoutProvider } from "../src/components/demo-layout-session";

import "../src/styles/index.css";

export const metadata: Metadata = {
  title: {
    default: "Chimwemwe local prototype",
    template: "%s · Chimwemwe local prototype",
  },
  description:
    "A local, synthetic browser prototype for evaluating the Chimwemwe experience foundation.",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const demoMode =
    process.env.CHIMWEMWE_DEMO_INSTANCE === "true" &&
    process.env.CHIMWEMWE_UI0_SYNTHETIC === "true";
  if (demoMode) await connection();
  return (
    <html lang="en">
      <body className="l-app-document">
        {demoMode ? (
          <DemoLayoutProvider
            defaultPackId={process.env.CHIMWEMWE_DEMO_PACK_ID ?? "unavailable"}
          >
            {children}
          </DemoLayoutProvider>
        ) : (
          children
        )}
      </body>
    </html>
  );
}
