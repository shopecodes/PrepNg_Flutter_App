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
- 🧪 **JAMB Mock Exam** — Full 4-subject mock exam simulation (Use of English + 3 chosen subjects)
- 🧠 **Question of the Day** — Daily challenge question with explanation, delivered via push notification at 9AM WAT
- 🔥 **Streaks** — Daily login and quiz streaks to keep students motivated
- 🏆 **Weekly Leaderboard** — Compete with other students, ranked by weekly quiz score
- 🔖 **Bookmarks** — Save questions to revisit later
- 📊 **Progress Tracking** — View full quiz history and mock exam results
- 🆓 **Free English Language** — JAMB Use of English is free for all users
- 💳 **Secure Payments** — Subject unlocking via Paystack (₦500 per subject)
- 🌐 **Offline Support** — Firebase offline persistence for studying without internet
- 🔔 **Push Notifications** — Daily QOTD alerts via Firebase Cloud Messaging
- 🔐 **User Authentication** — Secure login and account management via Firebase Auth

---

## 🛠️ Tech Stack

| Technology | Usage |
|---|---|
| Flutter | Cross-platform mobile development |
| Firebase Firestore | Cloud database for questions and user data |
| Firebase Auth | User authentication |
| Firebase Cloud Messaging | Push notifications |
| Firebase Cloud Functions | Scheduled QOTD notification delivery |
| Paystack | Payment processing |
| Provider | State management |
| Google Fonts | Typography (Poppins) |
| Connectivity Plus | Network status detection |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK
- Firebase project configured
- Paystack account
- Node.js 20+ (for Cloud Functions)

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
5. Deploy Firestore security rules: `firebase deploy --only firestore:rules`
6. Deploy Cloud Functions: `firebase deploy --only functions`

### Cloud Functions
The app uses two scheduled/HTTP Cloud Functions located in `functions/index.js`:

- **`sendQOTDNotification`** — Runs daily at 8:00 AM UTC (9:00 AM WAT), sends the Question of the Day push notification to all users with a valid FCM token
- **`testQOTDNotification`** — HTTP endpoint for testing. Accepts an optional `?date=YYYY-MM-DD` query parameter to send a notification for any specific date

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
│   ├── mock_exam/   # JAMB mock exam screens
│   ├── progress/    # Quiz history and progress
│   ├── quiz/        # Quiz screens
│   └── ...
├── services/        # Business logic
│   ├── auth_services.dart
│   ├── bookmark_service.dart
│   ├── connectivity_service.dart
│   ├── leaderboard_service.dart
│   ├── mock_exam_service.dart
│   ├── notification_service.dart
│   ├── progress_service.dart
│   ├── purchase_service.dart
│   ├── streak_service.dart
│   └── user_service.dart
└── utils/           # Utility functions
functions/
└── index.js         # Firebase Cloud Functions (QOTD scheduler)
```

---

## 🗃️ Firestore Data Structure

```
users/{uid}                          # User profiles + FCM tokens
streaks/{uid}                        # Daily streak tracking
leaderboard/{weekId}/scores/{uid}    # Weekly leaderboard scores
question_of_the_day/{YYYY-MM-DD}     # Daily QOTD documents
qotd_responses/{uid}/responses/{date}# User QOTD answers
subjects/{subjectId}                 # Subject metadata
questions/{questionId}               # Quiz questions
results/{resultId}                   # Quiz results
users/{uid}/bookmarks/{questionId}   # Saved/bookmarked questions
users/{uid}/mock_results/{resultId}  # Mock exam results
quiz_progress/{uid}/subjects/{id}    # Question deduplication (regular)
quiz_progress/{uid}/mock_subjects/{id} # Question deduplication (mock)
user_subjects/{id}                   # Unlocked subjects per user
purchases/{id}                       # Payment records
```

---

## 📖 How It Works

1. Student signs up and selects their department (Science, Arts, or Commercial)
2. They choose their exam scope — JAMB or WAEC
3. Use of English (JAMB) is free for all users
4. Other subjects are unlocked for ₦500 each via Paystack
5. Quiz sessions simulate real exam conditions with time limits
6. Mock exams combine Use of English + 3 chosen subjects for a full JAMB simulation
7. Progress is tracked and viewable after each session
8. Daily QOTD notifications keep students engaged every morning

---

## 🌐 Offline Behaviour

PrepNG is designed to work gracefully without internet:

- Firebase offline persistence caches previously loaded questions and data
- All screens that require network calls enforce a **10-second timeout**
- A snackbar notifies users when a connection attempt times out
- The leaderboard shows a **"Showing cached data"** banner when offline
- The app initialises from cache on startup — no internet required to open the app

---

## 🔒 Privacy & Security

- User data is stored securely in Firebase Firestore with strict security rules
- Payments are processed entirely by Paystack — no card data touches our servers
- Firebase Security Rules restrict each user to their own data only

See our full [Privacy Policy](https://shopecodes.github.io/prepng-privacy).

---

## 📄 License

This project is proprietary software. All rights reserved © 2026 PrepNG.

---

## 📬 Contact

For support or inquiries, please visit the app's Play Store page or open an issue in this repository.