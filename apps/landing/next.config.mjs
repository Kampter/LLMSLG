/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  typedRoutes: true,
  // The landing page never talks to apps/server directly — it's a static
  // marketing page. Keep transpilation focused on workspace types only.
  transpilePackages: ['@llmslg/types'],
};

export default nextConfig;
