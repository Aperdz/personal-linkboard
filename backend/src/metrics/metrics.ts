// Prometheus instrumentation — direct equivalent of Project 1's
// app/metrics.py. Same RED metrics: Rate, Errors, Duration.
import * as client from 'prom-client';

export const register = new client.Registry();
client.collectDefaultMetrics({ register }); // Node process metrics (memory, GC, etc.)

export const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status_code'],
  registers: [register],
});

export const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency in seconds',
  labelNames: ['method', 'path'],
  registers: [register],
});

export const redirectsTotal = new client.Counter({
  name: 'url_redirects_total',
  help: 'Total number of successful short-URL redirects',
  registers: [register],
});

export const linksCreatedTotal = new client.Counter({
  name: 'urls_created_total',
  help: 'Total number of short URLs created',
  registers: [register],
});
