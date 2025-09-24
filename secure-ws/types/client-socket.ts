import { Duplex } from 'stream';

export interface ClientSocket extends Duplex {
  id: string;
}