import { WebSocket } from "ws";
import { MockResponse as MockResponseType } from "../types/mock-response";

export class MockResponse implements MockResponseType {
  public socket: WebSocket;
  public statusCode: number = 200;

  constructor(socket: WebSocket) {
    this.socket = socket;
  }

  status(code: number) {
    this.statusCode = code;
    return this;
  }

  locals: Record<string, any> = {};

  send(data) {
    const responseType = this.statusCode >= 400 ? "error" : "success";
    this.socket.send(JSON.stringify({ 
      type: responseType,
      status: this.statusCode, 
      data: data 
    }));
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