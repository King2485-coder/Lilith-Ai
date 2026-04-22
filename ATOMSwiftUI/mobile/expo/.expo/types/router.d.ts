/* eslint-disable */
import * as Router from 'expo-router';

export * from 'expo-router';

declare module 'expo-router' {
  export namespace ExpoRouter {
    export interface __routes<T extends string = string> extends Record<string, unknown> {
      StaticRoutes: `/` | `/_sitemap` | `/admin-control` | `/application-builder` | `/browser` | `/chat` | `/cloud` | `/connected-apps` | `/growth-system` | `/guardian-dashboard` | `/home` | `/inbox` | `/kids-world` | `/library` | `/observability-dashboard` | `/onboarding` | `/profile` | `/system-dashboard` | `/tool-marketplace` | `/tools` | `/vault` | `/wallet` | `/workspace`;
      DynamicRoutes: `/run/${Router.SingleRoutePart<T>}` | `/session/${Router.SingleRoutePart<T>}` | `/site/${Router.SingleRoutePart<T>}` | `/view/${Router.SingleRoutePart<T>}`;
      DynamicRouteTemplate: `/run/[id]` | `/session/[id]` | `/site/[id]` | `/view/[id]`;
    }
  }
}
