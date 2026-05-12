import { IncomingMessage } from 'http';
import { WebSocket } from 'ws';
import { MockResponse } from '../mocks/express-response';
import { ExpressMiddleware } from '../types/express-middleware';
import { Request, Response } from 'express';

export function runExpressMiddleware(
  middleware: ExpressMiddleware,
  request: IncomingMessage,
  socket: WebSocket
): Promise<{ success: boolean; error?: string }> {
  return new Promise((resolve) => {
    const mockRes = new MockResponse(socket);
    let nextCalled = false;

    const next = (error?: any) => {
      if (nextCalled) return;
      nextCalled = true;
      
      if (error) {
        resolve({ success: false, error: error.message || 'Middleware error' });
      } else {
        resolve({ success: true });
      }
    };

    try {
      middleware(request as Request, mockRes as unknown as Response, next);
    } catch (error) {
      console.error("Middleware exception:", error);
      if (!nextCalled) {
        nextCalled = true;
        resolve({ success: false, error: error.message || 'Middleware exception' });
      }
    }
  });
}