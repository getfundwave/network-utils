import { WebSocket } from 'ws';

export interface ClientSocket extends WebSocket {
  id: string;
}