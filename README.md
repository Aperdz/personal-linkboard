# LinkBoard — Full-Stack + DevOps Demo

A URL shortener + click analytics app, built to demonstrate the same
DevOps pipeline as a companion Python project — but using the Node.js
ecosystem: **Next.js, NestJS, MongoDB, Redis, Docker, Kubernetes,
Prometheus, and Grafana.**

The point of this project isn't the app itself (deliberately simple) —
it's proving you can take a full-stack Node application through the full
containerize → deploy → scale → monitor pipeline.

---

## Architecture

```
 Browser ──▶ Next.js (frontend, port 3000)
                  │
                  ▼  fetch()
             NestJS API (backend, port 4000)
                  │              │
                  ▼              ▼
             MongoDB         Redis (cache, 5min TTL)
           (source of truth)
```

- **Next.js** — App Router, client component for the form/interactivity
- **NestJS** — controllers (routes) → services (business logic) → Mongoose (DB access)
- **MongoDB** — stores `{ shortCode, originalUrl, clickCount, createdAt }`
- **Redis** — cache layer in front of Mongo for fast redirects
- **Prometheus** — scrapes `/metrics` from the backend every 5s
- **Grafana** — visualizes request rate, latency, error rate, business metrics

---

## Running locally

```bash
cp .env.example .env
cp backend/.env.example backend/.env
docker compose up --build
```

- Frontend: http://localhost:3000
- Backend API + docs: http://localhost:4000
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001 (note: 3001, since 3000 is the frontend)

---

## Deploying to Kubernetes

```bash
kind create cluster --name linkboard-demo

docker build -t linkboard-backend:latest ./backend
docker build -t linkboard-frontend:latest \
  --build-arg NEXT_PUBLIC_API_URL=http://localhost:4000 ./frontend
kind load docker-image linkboard-backend:latest --name linkboard-demo
kind load docker-image linkboard-frontend:latest --name linkboard-demo

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/mongo.yaml
kubectl apply -f k8s/redis.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/networkpolicy.yaml

kubectl get pods -n linkboard -w
```

---

## Repo structure

```
linkboard/
├── backend/          # NestJS API
├── frontend/          # Next.js app
├── k8s/                # Kubernetes manifests
├── monitoring/         # Prometheus config + Grafana dashboard
├── docker-compose.yml
└── PRESENTATION.md      # demo runbook + talking-point script
```
