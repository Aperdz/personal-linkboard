// Mongoose schema — MongoDB's equivalent of the SQLAlchemy model in
// Project 1. Mongo is schemaless by default, but we define a schema
// anyway for validation and TypeScript type safety.
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type LinkDocument = Link & Document;

@Schema({ timestamps: true }) // adds createdAt/updatedAt automatically
export class Link {
  @Prop({ required: true, unique: true, index: true })
  shortCode: string;

  @Prop({ required: true })
  originalUrl: string;

  @Prop({ default: 0 })
  clickCount: number;
}

export const LinkSchema = SchemaFactory.createForClass(Link);
