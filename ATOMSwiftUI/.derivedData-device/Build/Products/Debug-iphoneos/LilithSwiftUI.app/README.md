# Lilith — SwiftUI Rewrite

Full feature-parity SwiftUI rewrite of the Lilith web frontend.

## Features

| Feature | Web (React) | SwiftUI |
|---------|-------------|---------|
| Authentication (login / register) | ✅ | ✅ |
| AI Chat — 5 agents, 4 modes, Ultra Thinking | ✅ | ✅ |
| Chat history (load, delete) | ✅ | ✅ |
| Code IDE — edit files, run code, auto-fix, HTML preview | ✅ | ✅ |
| Video generation — text-to-video | ✅ | ✅ |
| Video generation — from photo/video upload | ✅ | ✅ |
| Image generation | ✅ | ✅ |
| Site cloner — clone URL, view HTML, preview | ✅ | ✅ |
| Subscription plans (Stripe checkout) | ✅ | ✅ |
| Buy credit packages | ✅ | ✅ |
| Agent / Mode selector sheet | ✅ | ✅ |
| Super Admin badge & unlimited credits | ✅ | ✅ |

## Structure

```
LilithSwiftUI/
├── App/
│   ├── LilithSwiftUIApp.swift        Entry point
│   └── RootView.swift              Auth-gated root router
├── Core/
│   ├── Networking/APIClient.swift  URLSession JSON + multipart client
│   ├── Storage/SessionStorage.swift JWT persistence
│   └── UI/                         LilithTheme, GlassCard, PrimaryButtonStyle
└── Features/
    ├── Auth/                       LoginView, RegisterView, AuthStore
    ├── Landing/                    LandingView
    └── Workspace/
        ├── WorkspaceShellView.swift  7-tab shell + header bar
        ├── WorkspaceModels.swift     Shared enums & API model types
        ├── AgentSelectorSheet.swift  Mode + agent + Ultra Thinking sheet
        ├── SubscriptionSheet.swift   Plans & credits purchase sheet
        ├── Chat/                     ChatView, ChatViewModel, ChatModels
        ├── IDE/                      IDEView, IDEViewModel (code execution, auto-fix)
        ├── Media/
        │   ├── VideoView/ViewModel   Text-to-video + from-media upload
        │   └── ImageGenView          Image generation + save to Photos
        ├── Clone/                    CloneView, CloneViewModel (site cloner)
        ├── History/                  HistoryView, HistoryViewModel
        ├── Projects/                 ProjectsView (file CRUD, standalone)
        └── Account/                  AccountView (profile, admin stats)
```

## Requirements

- Xcode 15+, iOS 17 deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`

## Setup

```bash
# Install XcodeGen
brew install xcodegen

# Generate project
cd /path/to/project
xcodegen generate

# Open in Xcode
open Lilith.xcodeproj
```

## Configuration

Edit `APIClient.swift` → `APIConfig.baseURLString` to point at your backend:

```swift
enum APIConfig {
    static let baseURLString = "http://192.168.1.126:8000"   // local dev on LAN
    // static let baseURLString = "https://your-production-api.com"
}
```
