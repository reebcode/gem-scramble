# Gem Scramble

A competitive word scramble game built with Flutter and Flame.

## 🎮 Game Overview

Gem Scramble is a competitive word game where players:

- Join lobbies with different gem entry fees (10, 30, 50 gems, etc.)
- Play on 4x4 or 5x5 letter grids
- Find words by swiping adjacent letters
- Compete against other players in real-time
- Win gem prizes and rewards

## 🏗️ Architecture

### Tech Stack

**Frontend:**

- **Flutter** with Flame game engine
- **Provider** for state management
- **HTTP** for REST API communication
- **Material Design** with custom theming

**Backend:**

- **Node.js** with Express.js
- **TypeScript** for type safety
- **PostgreSQL** with Prisma ORM
- **Redis** for real-time match caching
- **Firebase Auth** for user authentication

### Project Structure

**Frontend:**

```
lib/
├── main.dart                 # App entry point
├── screens/                  # Main app screens
│   ├── lobby_screen.dart     # Lobby selection
│   ├── game_board_screen.dart # Game play
│   ├── results_screen.dart   # Match results
│   └── wallet_screen.dart    # Gem wallet management
├── components/               # Reusable UI components
│   ├── letter_tile.dart      # Game tile component
│   ├── animated_button.dart  # Custom button
│   └── timer_bar.dart        # Game timer
├── services/                 # Backend integration
│   ├── api_service.dart      # REST API client
│   ├── wallet_service.dart   # Gem wallet management
│   ├── matchmaking_service.dart # Game matching
│   └── gem_service.dart      # Gem transactions
├── models/                   # Data models
│   ├── user.dart            # User data
│   ├── match.dart           # Game match
│   ├── lobby.dart           # Lobby data
│   └── transaction.dart     # Gem transactions
└── animations/              # Game effects
    ├── tile_glow.dart       # Tile animations
    ├── coin_fly.dart        # Score animations
    └── confetti.dart        # Victory effects
```

**Backend:**

```
backend/
├── src/
│   ├── server.ts            # Express server setup
│   ├── modules/             # API route handlers
│   │   ├── matches.ts       # Match/game logic
│   │   ├── lobbies.ts       # Lobby management
│   │   ├── users.ts         # User management
│   │   ├── wallet.ts        # Gem transactions
│   │   └── validate.ts      # Word validation
│   ├── services/
│   │   ├── database.ts      # Prisma operations
│   │   └── dictionary.ts    # Word dictionary
│   ├── repositories/        # Data access layer
│   │   └── redisMatchRepository.ts  # Match caching
│   ├── config/              # Configuration
│   │   ├── lobbies.json     # Lobby types
│   │   └── prisma.ts        # Database setup
│   └── utils/               # Helper functions
├── prisma/
│   └── schema.prisma        # Database schema
└── docker-compose.yml       # Local development setup
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Node.js (>=16.0.0) for backend
- PostgreSQL (>=13.0) for database
- Redis (>=6.0) for caching
- Android Studio / VS Code
- iOS Simulator / Android Emulator

### Installation

1. **Clone the repository**

   ```
   git clone https://github.com/yourusername/gem-scramble.git
   cd gem-scramble
   ```

2. **Install Flutter dependencies**

   ```
   flutter pub get
   ```

3. **Install Backend dependencies**

   ```
   cd backend
   npm install
   ```

4. **Set up environment variables**

   ```
   # Create .env file in backend directory
   # Add your database credentials, Firebase config, etc.
   ```

5. **Set up the database**

   ```
   cd backend
   npx prisma migrate dev
   npx prisma generate
   ```

6. **Configure Firebase**

   ```
   # Copy Firebase configuration templates
   cp android/app/google-services.json.template android/app/google-services.json
   cp lib/firebase_options.dart.template lib/firebase_options.dart

   # Update with your Firebase project configuration
   ```

7. **Start the backend server**

   ```
   cd backend
   npm run dev
   ```

8. **Run the Flutter app**

   ```
   flutter run
   ```

### Configuration

1. **Firebase Setup**

   - Create a Firebase project at https://console.firebase.google.com
   - Enable Authentication and Firestore
   - Download `google-services.json` and place in `android/app/`
   - Generate `firebase_options.dart` using FlutterFire CLI

2. **Backend Configuration**

   - Update API endpoints in `lib/services/api_service.dart`
   - Configure database connection in `backend/.env`
   - Set up Redis instance for caching

### Backend Setup

1. **Start Docker Services**

   ```
   cd backend
   docker-compose up -d
   ```

   This starts PostgreSQL and Redis containers.

2. **Database Migration**

   ```
   cd backend
   npx prisma migrate dev
   npx prisma generate
   ```

3. **Environment Variables**
   Create `backend/.env` file:

   ```env
   DATABASE_URL="postgresql://scramble:password@localhost:5432/scramble"
   REDIS_URL="redis://localhost:6379"
   FIREBASE_PROJECT_ID="your-project-id"
   FIREBASE_PRIVATE_KEY="your-private-key"
   AUTH_MODE="dev"
   ```

   **Note:** The app runs in development mode by default (`AUTH_MODE="dev"`), which allows username-based login without Firebase authentication. For production, change to `AUTH_MODE="firebase"` and configure proper Firebase credentials.

4. **API Endpoints**
   - `GET /lobbies` - List available game lobbies
   - `POST /matches/join` - Join or create a match
   - `POST /matches/submit` - Submit words for scoring
   - `GET /matches/:matchId` - Get match details
   - `GET /users/me` - Get current user data
   - `GET /wallet/transactions` - Get transaction history

## 🎯 Features

### Core Gameplay

- **Real-time multiplayer** word scramble
- **Multiple difficulty levels** (Easy, Medium, Hard)
- **Different board sizes** (4x4, 5x5)
- **Timer-based matches** (5 minutes)
- **Server side word validation** and scoring

### Gem System

- **Gem wallet** for virtual currency
- **Bonus gems** for promotions and rewards
- **Gem transactions** for match entries and prizes
- **Transaction history** tracking
- **Secure gem management**

### User Experience

- **Smooth animations** and transitions
- **Responsive design** for all screen sizes
- **Push notifications** for match updates

## 🔧 Development

### Code Structure

- **Services**: Handle all backend communication
- **Models**: Define data structures with JSON serialization
- **Components**: Reusable UI elements with animations
- **Screens**: Main app views with state management

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

### Building

```bash
# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release

# Build for web
flutter build web --release
```

## 📱 Platform Support

- **Android**: API level 21+ (Android 5.0+)
- **iOS**: iOS 11.0+
- **Web**: Modern browsers with WebGL support
