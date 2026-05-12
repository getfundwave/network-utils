import { ExpressMiddleware } from "./express-middleware";
import { WSController } from "./ws-controller";

export type AddRouteParams = {
  onConnect: ExpressMiddleware[],
  onMessage: WSController[],
}