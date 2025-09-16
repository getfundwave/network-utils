import { IncomingMessage } from "http";

type HttpRequest = {
  headers?: Record<string, string>;
  body?: unknown;
};

export function injectHttpRequest(request: IncomingMessage, httpRequest: HttpRequest) {
  // Merge headers
  if (httpRequest.headers) {
    for (const [key, value] of Object.entries(httpRequest.headers)) {
      request.headers[key.toLowerCase()] = value;
    }
  }

  // Attach body as a custom property
  if (httpRequest.body) {
    (request as any).body = httpRequest.body;
  }

  return request;
}
