// Middleware that times + counts EVERY request — same job as Project 1's
// @app.middleware("http") in main.py.
import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { httpRequestsTotal, httpRequestDuration } from './metrics/metrics';

@Injectable()
export class MetricsMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const start = process.hrtime.bigint();
    res.on('finish', () => {
      const durationSec = Number(process.hrtime.bigint() - start) / 1e9;
      const path = req.route?.path || req.path;
      httpRequestsTotal.inc({ method: req.method, path, status_code: res.statusCode });
      httpRequestDuration.observe({ method: req.method, path }, durationSec);
    });
    next();
  }
}
