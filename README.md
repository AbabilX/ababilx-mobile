# AbabilX Mobile

[![Flutter](https://img.shields.io/badge/Flutter-SDK%20%5E3.12.0-blue.svg)](https://flutter.dev/)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen.svg)]()

**AbabilX** is a sophisticated Slack standup automation platform designed to streamline team communication and maintain developer activity. This mobile application allows users to manage automated Slack reports and GitHub commit schedules directly from their mobile devices with real-time notifications and AI-assisted previews.

---

## 🚀 Key Features

- **Slack Standup Automation**: Create and manage rules for automated messages to Slack channels. Includes AI-generated previews and manual overrides.
- **GitHub Auto-Commit**: Automate commits to designated repositories to maintain activity streaks.
- **Real-Time Notifications**: Integrated with Firebase Cloud Messaging (FCM) for pre-send reviews and status alerts.
- **AI Integration**: AI-powered message generation for standup reports.
- **Glassmorphic UI**: Modern, dark-themed interface utilizing glassmorphism effects and fluid animations.

---

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **State Management**: [Riverpod](https://riverpod.dev/) (with Code Generation)
- **Navigation**: [Go Router](https://pub.dev/packages/go_router)
- **Networking**: [Dio](https://pub.dev/packages/dio) with JWT interceptors
- **Backend Services**: [Firebase](https://firebase.google.com/) (Auth, messaging, core)
- **Local Storage**: [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- **Animations**: [Flutter Animate](https://pub.dev/packages/flutter_animate)
- **UI Components**: Google Fonts, Cached Network Image, Font Awesome (via Cupertino/Material)

---

## 📂 Project Structure (File-wise breakdown)

The project follows a feature-first architecture, separating core concerns from functional modules.

### `lib/` (Main Source)
- **[app.dart](lib/app.dart)**: The root widget `AbabilXApp`. Sets up the `MaterialApp.router`, global theme, and initializes FCM handlers.
- **[main.dart](lib/main.dart)**: Entry point. Initializes Firebase, configures background messaging, and bootstraps the Riverpod `ProviderScope`.
- **[firebase_options.dart](lib/firebase_options.dart)**: Auto-generated configuration for Firebase services.

### `lib/core/` (Foundational Logic)
- **[constants/](lib/core/constants/)**:
    - [api_constants.dart](lib/core/constants/api_constants.dart): Centralized API endpoints for the AbabilX backend.
    - [app_colors.dart](lib/core/constants/app_colors.dart): Brand colors and UI color definitions.
- **[localization/](lib/core/localization/)**: [app_translations.dart](lib/core/localization/app_translations.dart) for multi-language support (if applicable).
- **[network/](lib/core/network/)**:
    - [api_client.dart](lib/core/network/api_client.dart): Wrapper for Dio with interceptors for JWT injection and automated 401 (Unauthorized) handling.
- **[router/](lib/core/router/)**:
    - [app_router.dart](lib/core/router/app_router.dart): GoRouter configuration including auth guards and route definitions for all screens.
    - [home_shell.dart](lib/core/router/home_shell.dart): Bottom navigation shell containing Home, Rules, Auto-Commit, and Profile sections.
- **[session/](lib/core/session/)**: [authenticated_fetch.dart](lib/core/session/authenticated_fetch.dart) for session-specific logic.
- **[storage/](lib/core/storage/)**:
    - [secure_storage.dart](lib/core/storage/secure_storage.dart): Abstraction over `flutter_secure_storage` for storing JWTs and FCM tokens.
- **[theme/](lib/core/theme/)**: [app_theme.dart](lib/core/theme/app_theme.dart) defines the dark-themed design system.
- **[utils/](lib/core/utils/)**: General helper utilities like [date_utils.dart](lib/core/utils/date_utils.dart).

### `lib/features/` (Functional Modules)
- **[auth/](lib/features/auth/)**: Handles Google Sign-In via Firebase Auth and exchanges tokens for backend JWTs.
- **[auto_commit/](lib/features/auto_commit/)**: Manages GitHub commit automation jobs. Allows users to schedule commits per day and track monthly usage.
- **[home/](lib/features/home/)**: Provides a dashboard/activity feed showing recent events and system status.
- **[notifications/](lib/features/notifications/)**:
    - [fcm_handler.dart](lib/features/notifications/fcm_handler.dart): Manages foreground/background messaging and routes notification taps to specific app screens (e.g., Rule Preview).
    - [local_notification_service.dart](lib/features/notifications/local_notification_service.dart): Configures local system notifications for foreground alerts.
- **[profile/](lib/features/profile/)**: User profile management and account settings.
- **[rules/](lib/features/rules/)**: The core functionality. Allows users to define Slack standup rules, preview AI-generated content, and review message history.

### `lib/shared/` (Reusable UI)
- **[widgets/](lib/shared/widgets/)**:
    - [glass_card.dart](lib/shared/widgets/glass_card.dart): A custom BackdropFilter-based card for glassmorphic effects.
    - [gradient_button.dart](lib/shared/widgets/gradient_button.dart): Standardized brand-colored buttons.
    - [loading_overlay.dart](lib/shared/widgets/loading_overlay.dart): Global spinner for async operations.
    - [rule_status_badge.dart](lib/shared/widgets/rule_status_badge.dart): Status indicators for Slack rules.

---

## ⚙️ Setup Instructions

### Prerequisites
- Flutter SDK `^3.12.0`
- Android Studio / VS Code with Flutter extension
- Firebase Project (configured for Android/iOS)

### Installation
1.  **Clone the repository**:
    ```bash
    git clone https://github.com/your-repo/ababilx-mobile.git
    cd ababilx-mobile
    ```
2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Run Build Runner** (for Riverpod/Freezed code-gen):
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```
4.  **Configure Firebase**:
    Ensure you have `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in the respective locations. Use `flutterfire configure` to regenerate `lib/firebase_options.dart`.

5.  **Run the app**:
    ```bash
    flutter run
    ```

---

## 📜 License

This project is proprietary and confidential. Unauthorized copying of these files, via any medium, is strictly prohibited.

---
*Created with ❤️ by the AbabilX Team.*

