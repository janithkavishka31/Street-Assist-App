# Folder layout (MVC)

```
StreetAssistIOS/
  App/
  Controllers/
  Models/
  Views/
  Services/
  Networking/
  Resources/
  SupportingFiles/
  Utilities/
  Tests/
```

## Conventions
- Controllers: screen-level flow + user interaction handlers; call `Services/`.
- Views: reusable UI components (UIKit views / SwiftUI views).
- Models: DTOs + domain models; keep them independent of UI.
- Networking: low-level HTTP client + endpoints + request/response structs.
- Services: domain services (Auth, Location, Persistence) built on Networking.
- Utilities: extensions, helpers, constants.
- App: app entry/composition and global configuration.
