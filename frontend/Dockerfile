# =============================================================================
# STAGE 1: "deps" — install dependencies (cached separately from source)
# =============================================================================
FROM node:20-slim AS deps
WORKDIR /build
COPY package*.json ./
RUN npm ci

# =============================================================================
# STAGE 2: "builder" — build the Next.js production bundle
# =============================================================================
FROM node:20-slim AS builder
WORKDIR /build
COPY --from=deps /build/node_modules ./node_modules
COPY . .
# NEXT_PUBLIC_* vars must be present at BUILD time, not just runtime —
# they get baked into the client-side JavaScript bundle. This is a real
# Next.js gotcha worth knowing and mentioning in the interview.
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN npx next build

# =============================================================================
# STAGE 3: "runtime" — minimal server using Next's 'standalone' output
# =============================================================================
# next.config.js has `output: 'standalone'`, which makes Next.js trace
# only the files actually needed at runtime and copy them into
# .next/standalone. This is dramatically smaller than shipping the full
# node_modules folder — the direct Next.js equivalent of Project 1's
# multi-stage size savings.
FROM node:20-slim AS runtime

RUN groupadd -r appgroup && useradd -r -g appgroup -d /app appuser
WORKDIR /app

COPY --from=builder /build/.next/standalone ./
COPY --from=builder /build/.next/static ./.next/static
COPY --from=builder /build/public ./public

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000', r => process.exit(r.statusCode < 500 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]
