# secure-ws

secure-ws is a TypeScript library for secure WebSocket servers that lets you run Express-style middleware during the upgrade handshake, ensuring unauthenticated connections are never left open.

## Why use secure-ws

- Run middleware during the WebSocket upgrade handshake
- Reuse Express Middlewares for authentication, validation and more
- Abstract away connection, upgrade, and messaging with Express-style routes, middleware, and controllers.

## Installation

```
npm install --save secure-ws
```

## Usage

```typescript
import express from "express";
import { WebSocketProvider } from 'websocket-provider';

const wsApp = new WebSocketProvider();
const app = express();

// app.get...
// app.post...

wsApp.addRoute(
  "/extract/metrics",
  {
    onConnect: [authMiddleware1, authMiddleware2],
    onMessage: [controller]
  }
);

const httpServer = app.listen(PORT, () => {
  console.info(`File service running at http://localhost:${PORT}`);
});

httpServer.on('upgrade', wsApp.handleUpgrade);
```

## License

MIT
