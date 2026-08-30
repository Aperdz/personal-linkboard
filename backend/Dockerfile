# =============================================================================
# STAGE 1: "builder" — install ALL deps (including dev deps) and compile
#          TypeScript into plain JavaScript
# =============================================================================
# Same multi-stage philosophy as Project 1's Python Dockerfile: the build
# stage needs things (TypeScript compiler, type definitions, dev tooling)
# that the running app never needs. We throw all of that away afterward.
FROM node:20-slim AS builder

WORKDIR /build

# Copy only package files first — same Docker layer-caching trick as
# Project 1: if dependencies haven't changed, this expensive npm install
# layer is reused from cache on rebuilds.
COPY package*.json ./
RUN npm ci

# Now copy source and compile TypeScript -> JavaScript (output: dist/)
COPY tsconfig.json nest-cli.json ./
COPY src/ ./src/
RUN npx nest build


# =============================================================================
# STAGE 2: "runtime" — only production dependencies + compiled JS
# =============================================================================
FROM node:20-slim AS runtime

# --- SECURITY: non-root user, same reasoning as Project 1 -------------------
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app appuser

WORKDIR /app

# Install ONLY production dependencies this time (no TypeScript, no
# @types/*, no ts-jest) — this is the Node equivalent of Project 1's
# builder stage discarding gcc/libpq-dev.
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy only the compiled output from the builder stage — we never copy
# the TypeScript source into the final image.
COPY --from=builder /build/dist ./dist

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:4000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "dist/main.js"]
