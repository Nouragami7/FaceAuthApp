## Quick orientation for AI coding agents

This repository is a Flutter mobile app focused on face recognition. The goal of these instructions is to give an agent the minimum, high-value knowledge to be productive immediately.

Key locations
- `lib/main.dart` — app entrypoint. It creates an `AppDatabase` and provides it to the widget tree via `RepositoryProvider`.
- `lib/core/database/app_database.dart` — central DB layer (Drift). Codegen is enabled via `drift_dev` + `build_runner` in `pubspec.yaml`.
- `lib/config/route/route_generator.dart` and `lib/config/route/routes.dart` — routing centralization; use `AppRoutes` values instead of hard-coded strings.
- `lib/feature/` — feature modules (UI, BLoC, data). Look here for domain-specific implementations.
- `pubspec.yaml` — lists key integrations: `camera`, `google_mlkit_face_detection`, `flutter_exif_rotation`, `drift`, `flutter_bloc`, `image_picker`.

Big-picture architecture notes
- App uses a layered structure: `config` for routing and app wiring, `core` for shared infrastructure (DB, utils), and `feature` for domain features.
- State management: `flutter_bloc` / `bloc` + `provider` patterns are present. Many components are provided via repository/provider at top-level (see `main.dart`).
- Persistence: `drift` (aka moor) is used. Expect generated code — run the build_runner step when editing schemas.
- Machine learning: face detection is performed via ML Kit (`google_mlkit_face_detection`). Camera capture is handled by the `camera` plugin and images may be rotated/normalized using `flutter_exif_rotation`.

Concrete, reproducible commands
- Install deps: `flutter pub get`
- Run app (debug): `flutter run -d <device-id>` (PowerShell: the command is the same)
- Build Android APK: `flutter build apk --release`
- Run unit/widget tests: `flutter test`
- Regenerate Drift DB and other generated files: `flutter pub run build_runner build --delete-conflicting-outputs`

Project-specific conventions and patterns
- Routes: prefer `AppRoutes.<name>` + `RouteGenerator.generateRoute` instead of ad-hoc `Navigator.pushNamed` strings.
- DB access: `AppDatabase` is created in `main.dart` and provided via `RepositoryProvider.value(value: appDb)`. Components expect to obtain DB via DI.
- ML + camera flow: the project uses the `camera` plugin to get frames and then calls ML Kit face detection (`google_mlkit_face_detection`) — check `feature/*/presentation` for how frames are converted to inputs. When adding native-model assets, place them under `assets/` and update `pubspec.yaml`.
- Codegen: any change to Drift table/schema or annotated files requires running build_runner. Use the `--delete-conflicting-outputs` flag in CI to avoid merge conflicts.

Integration points & important dependencies
- Native platforms: Android (Gradle wrapper present), iOS (Xcode project under `ios/Runner`). When debugging native failures, look at `android/` or `ios/` folders.
- ML: `google_mlkit_face_detection` — image orientation and cropping are important; prefer using `flutter_exif_rotation` before feeding images to the detector.
- Local DB: `drift` + `sqlite3_flutter_libs`. DB file initialization happens in `AppDatabase`.

Examples (where to look)
- To see app wiring: open `lib/main.dart`.
- To see route names and navigation: open `lib/config/route/routes.dart` and `lib/config/route/route_generator.dart`.
- To inspect face-detection usage: search `google_mlkit_face_detection` or check `lib/feature/**/` for detector wrappers.

Checks an agent should run before PRs
- Run `flutter analyze` / `flutter test` and `flutter pub run build_runner build` to ensure no missing generated files.
- Verify the app launches on an emulator or device and that camera + ML flows run (smoke test).

If something is missing
- If you need the exact DB schema or generated files, run build_runner locally and commit generated artifacts (if the project expects them) or ask the maintainer whether generated sources should be committed.

Feedback
Please review these notes and tell me if you'd like me to:
- add CI steps (GitHub Actions) that run `flutter test` and `build_runner`,
- include examples of common edits (adding a new route, a new Drift table), or
- extract additional conventions from specific feature folders.

— End
