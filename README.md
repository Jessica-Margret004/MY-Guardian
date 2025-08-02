# Guardian – Personal Safety App

**Guardian** is a cross-platform mobile safety application built using Flutter and Firebase. The app is designed to help users respond quickly in emergencies, report incidents, and stay informed through AI-driven interactions.

## 🔐 Key Features
- **SOS Alerts** – One-tap emergency help
- **AI Chatbot** – Voice-enabled and sentiment-aware assistant
- **Incident Reporting** – Submit reports with image, place, cause
- **Location-Based Warnings** – Real-time alerts via Firestore
- **Safety Tips** – Auto-fetched tips for everyday protection
- **Firebase Auth** – Secure login and user management

## 🛠️ Tech Stack
- **Flutter & Dart**
- **Firebase (Auth, Firestore, Storage)**
- **Google Maps API**
- **Text-to-Speech + Voice Input**
- **Custom Sentiment Detection**

## 📁 Folder Structure
├── screens/
│ ├── chatbot_screen.dart
│ ├── sign_in_screen.dart
│ ├── sign_up_screen.dart
│ ├── profile_setup_screen.dart
│ ├── safety_screen.dart
│ └── incident_report.dart
├── services/
│ ├── chatbot_service.dart
│ ├── auth_service.dart
│ └── firestore_service.dart
└── main.dart

## 🚫 Excluded Files
For security, this repo does not include:
- `firebaseConfig.js` / `google-services.json`
- `.env` or sensitive credentials
- Real user data or test images
