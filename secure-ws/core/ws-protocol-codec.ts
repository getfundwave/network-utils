export class WSProtocolCodec {
  static encode(data: unknown): string {
    const json = JSON.stringify(data);
    return btoa(json)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  }

  static decode<T = unknown>(encoded: string): T {
    let str = encoded.replace(/-/g, "+").replace(/_/g, "/");
    while (str.length % 4) str += "=";
    const json = atob(str);
    return JSON.parse(json) as T;
  }
}
