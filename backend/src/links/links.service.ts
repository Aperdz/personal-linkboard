// Business logic layer — same role as crud.py in Project 1.
// SECURITY: generateShortCode uses Node's crypto module (CSPRNG),
// same reasoning as Project 1's fix (secrets.choice over random.choices).
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { randomInt } from 'crypto';
import Redis from 'ioredis';
import { Link, LinkDocument } from './link.schema';

const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const CODE_LENGTH = 7;
const CACHE_TTL_SECONDS = 300;

function generateShortCode(): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += ALPHABET[randomInt(0, ALPHABET.length)];
  }
  return code;
}

@Injectable()
export class LinksService {
  private redis: Redis;

  constructor(@InjectModel(Link.name) private linkModel: Model<LinkDocument>) {
    this.redis = new Redis({
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT || '6379', 10),
      lazyConnect: false,
      maxRetriesPerRequest: 1,
    });
  }

  async createLink(originalUrl: string): Promise<LinkDocument> {
    // Retry a few times on the very unlikely chance of a code collision —
    // same pattern as Project 1's crud.create_short_url.
    for (let attempt = 0; attempt < 5; attempt++) {
      const shortCode = generateShortCode();
      const existing = await this.linkModel.findOne({ shortCode });
      if (!existing) {
        return this.linkModel.create({ shortCode, originalUrl, clickCount: 0 });
      }
    }
    throw new Error('Could not generate a unique short code');
  }

  async getStats(shortCode: string): Promise<LinkDocument> {
    const link = await this.linkModel.findOne({ shortCode });
    if (!link) throw new NotFoundException('Short code not found');
    return link;
  }

  async resolveAndTrackClick(shortCode: string): Promise<string> {
    // Cache-first read, same pattern as Project 1's redirect handler.
    const cached = await this.redis.get(`url:${shortCode}`);
    let originalUrl = cached;

    if (!originalUrl) {
      const link = await this.linkModel.findOne({ shortCode });
      if (!link) throw new NotFoundException('Short URL not found');
      originalUrl = link.originalUrl;
      await this.redis.setex(`url:${shortCode}`, CACHE_TTL_SECONDS, originalUrl);
    }

    await this.linkModel.updateOne({ shortCode }, { $inc: { clickCount: 1 } });
    return originalUrl;
  }

  async pingDependencies(): Promise<void> {
    await this.linkModel.db.db?.admin().ping();
    await this.redis.ping();
  }
}
