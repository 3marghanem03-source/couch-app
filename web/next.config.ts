import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Monorepo: avoid picking a parent folder lockfile as the tracing root.
  outputFileTracingRoot: path.join(__dirname),
};

export default nextConfig;
