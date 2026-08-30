import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Global validation — rejects malformed request bodies before they
  // reach any controller, using the DTO rules in create-link.dto.ts.
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // CORS enabled so the Next.js frontend (different port/origin) can call this API.
  app.enableCors();

  const port = process.env.PORT || 4000;
  await app.listen(port);
  console.log(`LinkBoard API running on port ${port}`);
}
bootstrap();
