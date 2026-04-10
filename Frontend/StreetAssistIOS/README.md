# StreetAssist iOS (Swift) — Frontend

This folder holds the iOS app source organized in a simple MVC-style structure.

## Structure
- `App/` — app entry + app-wide composition (App/Scene delegate, coordinators if you add them later)
- `Controllers/` — `UIViewController` (or SwiftUI hosting controllers) that coordinate UI + call services
- `Views/` — reusable UI views (UIKit `UIView` / SwiftUI `View`), cells, and view components
- `Models/` — plain models (DTOs, domain structs), validation, mapping
- `Networking/` — HTTP client, endpoints, request/response types
- `Services/` — higher-level services (e.g., auth, location, persistence) used by controllers
- `Utilities/` — extensions, helpers, constants
- `Resources/` — assets, localization, fonts
- `SupportingFiles/` — Info.plist, entitlements, build configs (once created via Xcode)
- `Tests/` — unit tests

## Notes
- Create the actual Xcode project (`.xcodeproj` / `.xcworkspace`) in `Frontend/` (or inside `StreetAssistIOS/`) and point its groups to these folders.
- Keep controllers thin: networking/persistence goes into `Services/` + `Networking/`.
