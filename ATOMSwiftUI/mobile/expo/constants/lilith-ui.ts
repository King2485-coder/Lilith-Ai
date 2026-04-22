export type LilithScreenKey =
  | "home"
  | "chat"
  | "browser"
  | "wallet"
  | "library"
  | "workspace"
  | "vault"
  | "cloud"
  | "tools"
  | "inbox"
  | "profile"
  | "kids-world"
  | "guardian-dashboard"
  | "admin-control"
  | "observability-dashboard"
  | "growth-system"
  | "tool-marketplace";

export type LilithScreenDef = {
  key: LilithScreenKey;
  title: string;
  route: string;
  subtitle: string;
};

export const LILITH_SCREENS: LilithScreenDef[] = [
  { key: "home", title: "Home", route: "/home", subtitle: "Command center" },
  { key: "chat", title: "Chat", route: "/chat", subtitle: "Communication core" },
  { key: "browser", title: "Browser", route: "/browser", subtitle: "Internet layer" },
  { key: "wallet", title: "Wallet", route: "/wallet", subtitle: "Lilith Pay" },
  { key: "library", title: "Library", route: "/library", subtitle: "Saved content vault" },
  { key: "workspace", title: "Workspace", route: "/workspace", subtitle: "Active work in progress" },
  { key: "vault", title: "Vault", route: "/vault", subtitle: "Highly secure personal data" },
  { key: "cloud", title: "Cloud", route: "/cloud", subtitle: "Sync and backup controls" },
  { key: "tools", title: "Tools", route: "/tools", subtitle: "Abilities system" },
  { key: "inbox", title: "Inbox", route: "/inbox", subtitle: "Unified stream" },
  { key: "profile", title: "Profile", route: "/profile", subtitle: "Identity hub" },
  { key: "kids-world", title: "Kids World", route: "/kids-world", subtitle: "Safe immersive world" },
  { key: "guardian-dashboard", title: "Guardian", route: "/guardian-dashboard", subtitle: "Safety controls" },
  { key: "admin-control", title: "Admin", route: "/admin-control", subtitle: "Platform control" },
  { key: "observability-dashboard", title: "Observability", route: "/observability-dashboard", subtitle: "Live systems" },
  { key: "growth-system", title: "Growth", route: "/growth-system", subtitle: "Audience growth" },
  { key: "tool-marketplace", title: "Marketplace", route: "/tool-marketplace", subtitle: "Discover & monetize" },
];
