// Root module — wires everything together. Same job as the FastAPI
// app object in Project 1's main.py, but Nest is explicit about
// module boundaries (a deliberate architectural difference worth
// mentioning in your presentation: Nest enforces structure, Fast
// API leaves it to you).
import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ConfigModule } from '@nestjs/config';
import { Link, LinkSchema } from './links/link.schema';
import { LinksController } from './links/links.controller';
import { LinksService } from './links/links.service';
import { HealthController } from './health/health.controller';
import { MetricsMiddleware } from './metrics.middleware';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    MongooseModule.forRoot(
      process.env.MONGODB_URI || 'mongodb://localhost:27017/linkboard',
    ),
    MongooseModule.forFeature([{ name: Link.name, schema: LinkSchema }]),
  ],
  // IMPORTANT: HealthController must be registered BEFORE LinksController.
  // LinksController has a catch-all route `GET /:code` (the redirect
  // handler) which would otherwise match "/health" and "/metrics" as if
  // they were short codes, since NestJS/Express match routes in
  // registration order. Registering the more specific routes first
  // avoids that collision.
  controllers: [HealthController, LinksController],
  providers: [LinksService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(MetricsMiddleware).forRoutes('*');
  }
}