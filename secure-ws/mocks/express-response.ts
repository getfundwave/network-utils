import { WebSocket } from "ws";
import { MockResponse as MockResponseType } from "../types/mock-response";

export class MockResponse implements MockResponseType {
  private socket: WebSocket;
  public statusCode: number = 200;

  constructor(socket: WebSocket) {
    this.socket = socket;
  }

  status(code: number) {
    this.statusCode = code;
    return this;
  }

  send(data) {
    this.socket.send(`HTTP/1.1 ${this.statusCode} ${this.getStatusText()}\r\n\r\n`);
    this.socket.close();
    return this;
  }

  sendStatus(code: number) {
    this.statusCode = code;
    const responseType = code >= 400 ? "error" : "success";
    this.socket.send(JSON.stringify({ 
      status: code, 
      statusText: this.getStatusText(),
      type: responseType 
    }));
    this.socket.close();
    return this;
  }

  private getStatusText(): string {
    const statusTexts: { [key: number]: string } = {
      200: 'OK',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'Not Found',
      500: 'Internal Server Error'
    };
    return statusTexts[this.statusCode] || 'Unknown';
  }
};