// types/mock-response.ts
import { WebSocket } from "ws";

export interface MockResponse {
  socket: WebSocket;
  status(code: number): this;
  send(data: any): this;
  sendStatus(code: number): this;
  locals: Record<string, any>;
}
