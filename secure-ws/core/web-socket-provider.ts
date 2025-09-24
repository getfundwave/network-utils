import { WebSocketServer, WebSocket as WSWebSocket } from 'ws';
import { IncomingMessage } from 'http';
import { decode } from "@msgpack/msgpack";
import { randomUUID } from "crypto";

import { WSProtocolCodec } from './ws-protocol-codec';
import { runExpressMiddleware } from '../utils/middleware-adapter';
import { injectHttpRequest } from '../utils/inject-http-request';

import { WSController } from '../types/ws-controller';
import { AddRouteParams } from '../types/add-route-params';
import { ClientSocket } from '../types/client-socket';

export class WebSocketProvider {
  public server: WebSocketServer;
  private routes: Record<string, AddRouteParams>;

  constructor() {
    this.server = new WebSocketServer({ noServer: true });
    this.server.on('connection', this.handleConnection);
    this.routes = {};
  }

  public addRoute = (
    path: string, 
    {
      onConnect,
      onMessage,
    } : AddRouteParams
  ) => {
    this.routes[path] = {
      onConnect,
      onMessage
    }
  }
  public handleUpgrade = (request: IncomingMessage, socket: ClientSocket, head: Buffer) => {
    const { pathname } = new URL(request.url!, 'wss://base.url');
    
    if (this.routes[pathname]) {
      socket.id = `${Date.now()}-${randomUUID()}`;
      this.server.handleUpgrade(request, socket, head, (ws: WSWebSocket) => {
        this.server.emit('connection', ws, request);
      });
    } else {
      console.log('No route for path:', pathname);
      socket.end();
    }
  };

  private handleConnection = async (ws: WSWebSocket, request: IncomingMessage) => {
    const { pathname } = new URL(request.url!, 'wss://base.url');

    let injectedRequest = {} as IncomingMessage;

    if (typeof ws.protocol === 'string' && ws.protocol.trim() !== '') {
      const httpRequest = WSProtocolCodec.decode(ws.protocol);
      injectedRequest = injectHttpRequest(request, httpRequest);
    }

    if(!this.routes[pathname]) {
      ws.close(1000, 'Unknown path');
      return;
    }

    const { onConnect, onMessage } = this.routes[pathname];
    
    for (const middleware of onConnect) {
      const res = await runExpressMiddleware(middleware, injectedRequest, ws);
      if (!res.success) {
        console.error("Middleware rejected connection:", res.error);
        ws.send(JSON.stringify({ error: res.error }));
        ws.close(1000, res.error);
        return;
      }
    }

    ws.on('message', this.handleMessage(ws, onMessage));
    ws.send(JSON.stringify({ type: "connection:ack" }));
  };

  private handleMessage = (socket: WSWebSocket, onMessage: WSController[]) => {
    return async (message) => {
      const request = decode(message) as IncomingMessage;

      for (const controller of onMessage) {
        await controller(request, socket);
      }
    };
  }
}