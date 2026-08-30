/** @type {import('next').NextConfig} */
const nextConfig = {
  // 'standalone' output produces a minimal, self-contained server build —
  // this is what makes the Docker image small (see Dockerfile comments).
  output: 'standalone',
};
module.exports = nextConfig;
