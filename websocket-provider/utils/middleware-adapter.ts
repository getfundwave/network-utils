import { IncomingMessage } from 'http';
import { WebSocket } from 'ws';
import { MockResponse } from '../mocks/express-response';

export function runExpressMiddleware(
  middleware: (req, res, next) => void,
  request: IncomingMessage,
  socket: WebSocket
): Promise<{ success: boolean; error?: string }> {
  return new Promise((resolve) => {
    const mockRes = new MockResponse(socket);
    let nextCalled = false;

    const next = (error) => {
      if (nextCalled) return;
      nextCalled = true;
      
      if (error) {
        resolve({ success: false, error: error.message || 'Middleware error' });
      } else {
        resolve({ success: true });
      }
    };

    const originalSend = mockRes.send.bind(mockRes);
    const originalSendStatus = mockRes.sendStatus.bind(mockRes);

    mockRes.send = (data) => {
      if (!nextCalled) {
        nextCalled = true;
        resolve({ success: false, error: `HTTP ${mockRes.statusCode}` });
      }
      return mockRes;
    };

    mockRes.sendStatus = (code: number) => {
      if (!nextCalled) {
        nextCalled = true;
        resolve({ success: false, error: `HTTP ${code}` });
      }
      return mockRes;
    };

    try {
      middleware(request, mockRes, next);
    } catch (error) {
      console.error("Middleware exception:", error);
      if (!nextCalled) {
        nextCalled = true;
        resolve({ success: false, error: error.message || 'Middleware exception' });
      }
    }
  });
}