// types/mock-response.ts
export interface MockResponse {
  status(code: number): this;
  send(data: any): this;
  sendStatus(code: number): this;
  locals: Record<string, any>;
}
