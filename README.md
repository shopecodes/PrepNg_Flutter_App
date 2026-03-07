# PrepNG - JAMB & WAEC Exam Preparation App

<p align="center">
  <img src="assets/images/bookillustration1.png" width="120" alt="PrepNG Logo"/>
</p>

<p align="center">
  <strong>The smartest way for Nigerian students to prepare for JAMB (UTME) and WAEC (SSCE) exams.</strong>
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.shorpe.prepng">
    <img src="https://img.shields.io/badge/Download-Google%20Play-green?style=for-the-badge&logo=google-play" alt="Google Play"/>
  </a>
</p>

---

## 📱 About PrepNG

PrepNG is a Flutter-based mobile application designed to help Nigerian secondary school students prepare effectively for their JAMB (UTME) and WAEC (SSCE) examinations. All questions are strictly based on the **official current syllabus** downloaded directly from the JAMB and WAEC websites — not recycled past questions.

The app covers **51 subjects** across both exam scopes, with questions updated annually to match the latest syllabus.

---

## ✨ Features

- 🎯 **JAMB & WAEC Coverage** — 51 subjects across both exam scopes
- 📚 **Syllabus-Based Questions** — 120+ questions per subject, based on official current syllabus
- ⏱️ **Exam Simulation** — 40 questions in 30 mins (JAMB) / 60 questions in 60 mins (WAEC)
- 🆓 **Free English Language** — JAMB English is free for all users
- 💳 **Secure Payments** — Subject unlocking via Paystack (₦500 per subject)
- 📊 **Progress Tracking** — View and manage your quiz history
- 🌐 **Offline Support** — Firebase offline persistence for studying without internet
- 🔐 **User Authentication** — Secure login and account management via Firebase Auth

---

## 🛠️ Tech Stack

| Technology | Usage |
|---|---|
| Flutter | Cross-platform mobile development |
| Firebase Firestore | Cloud database for questions and user data |
| Firebase Auth | User authentication |
| Paystack | Payment processing |
| Provider | State management |
| Google Fonts | Typography (Poppins) |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK
- Firebase project configured
- Paystack account

### Installation

```bash
# Clone the repository
git clone https://github.com/shopecodes/PrepNg_Flutter_App.git

# Navigate to project directory
cd PrepNg_Flutter_App

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Firebase Setup
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add your Android app and download `google-services.json`
3. Place it in `android/app/`
4. Run `flutterfire configure` to generate `firebase_options.dart`

### Paystack Setup
1. Create a Paystack account at [paystack.com](https://paystack.com)
2. Add your public and secret keys to `lib/config/paystack_config.dart`

---

## 📂 Project Structure

```
lib/
├── config/          # App configuration (Paystack keys, etc.)
├── models/          # Data models
├── provider/        # State management (Provider)
├── screens/         # UI screens
│   ├── auth/        # Login, signup, profile
│   ├── quiz/        # Quiz screens
│   └── ...
├── services/        # Business logic (auth, purchase, connectivity)
└── utils/           # Utility functions
```

---

## 📖 How It Works

1. Student signs up and selects their department (Science, Arts, or Commercial)
2. They choose their exam scope — JAMB or WAEC
3. English Language (JAMB) is free for all users
4. Other subjects are unlocked for ₦500 each via Paystack
5. Quiz sessions simulate real exam conditions with time limits
6. Progress is tracked and viewable after each session

---

## 🔒 Privacy & Security

- User data is stored securely in Firebase Firestore
- Payments are processed entirely by Paystack — no card data touches our servers
- Firebase Security Rules restrict each user to their own data only

See our full [Privacy Policy](https://shopecodes.github.io/prepng-privacy).

---

## 📄 License

This project is proprietary software. All rights reserved © 2025 PrepNG.

---

## 📬 Contact

For support or inquiries, please visit the app's Play Store page or open an issue in this repository.
