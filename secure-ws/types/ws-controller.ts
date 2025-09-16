import { WebSocket } from 'ws';

export type WSController = (message: any, socket: WebSocket) => any;