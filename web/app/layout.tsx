import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Coach Sessions (web)",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
