# Route Memory 📍

**Route Memory** is a professional-grade GPS tracking and navigation application. It allows users to record journeys with high precision, sync them to the cloud, and retrace their steps using hybrid navigation logic.

> **Status:** Active Development (v1.2.0 Alpha)

## ✨ Key Features

### 🛰️ Professional Tracking

-   **High-Fidelity GPS:** Captures location every second with background foreground service support (keeps tracking when screen is off).
    
-   **Smart Filtering:** Ramer-Douglas-Peucker algorithm simplifies routes to save storage without losing shape.
    
-   **Live Dashboard:** Real-time stats for distance, duration, and speed.
    

### ☁️ Cloud & Data

-   **Firebase Integration:** All routes and saved places are synced to Cloud Firestore.
    
-   **User Accounts:** Supports Email/Password login and Anonymous guest access.
    
-   **Cross-Device Sync:** Access your tracking history on any Android device.
    

### 🗺️ Intelligent Navigation

-   **Hybrid Routing:**
    
    -   _Road Snap:_ Uses OSRM API to find the fastest driving path.
        
    -   _Breadcrumb Mode:_ Retrace your exact recorded path ("Ghost Path") when off-road.
        
-   **Dynamic Search:** Google Maps-style search bar with debounced API calls for finding places instantly.
    
-   **Heads-Up Display:** "North-Up" vs "Heads-Up" (Compass) rotation modes.
    

### 🎨 Modern UI/UX

-   **Dynamic Theming:** Fully supports System, Light, and Dark modes.
    
-   **Performance Profiles:** Toggle between "Battery Saver" (static map) and "High Fidelity" (smooth rotation).
    
-   **Interactive History:** View lifetime stats and manage routes with long-press actions.
    

## 🛠️ Tech Stack

-   **Framework:** Flutter (Dart)
    
-   **State Management:** Riverpod (Feature-first architecture)
    
-   **Backend:** Firebase Auth & Cloud Firestore
    
-   **Maps:** `flutter_map` + OpenStreetMap Tiles
    
-   **Routing API:** OSRM (Open Source Routing Machine)
    
-   **Search API:** Nominatim (OpenStreetMap)
    
-   **Sensors:** `geolocator` (GPS), `flutter_compass` (Bearing)
    

## 🚀 Getting Started

### Prerequisites

-   Flutter SDK (3.0.0+)
    
-   Android Studio / VS Code
    
-   A physical Android device (Simulators cannot emulate GPS movement effectively).
    

### Installation

1.  **Clone the repository**
    
        git clone https://github.com/sasidharakurathi/route-memory.git
        
        cd route-memory
        
    
2.  **Install dependencies**
    
        flutter pub get
        
    
3.  **Firebase Setup (Crucial)**
    
    -   Create a project at [console.firebase.google.com](https://console.firebase.google.com/ "null").
        
    -   Enable **Authentication** (Email/Anonymous) and **Firestore Database**.
        
    -   Download `google-services.json` and place it in `android/app/`.
        
4.  **Run the app**
    
        flutter run

## 📱 Permissions

**Android:** The app requires the following permissions in `AndroidManifest.xml`:

    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.INTERNET" />
    

## 🤝 Contributing

1.  Fork the project
    
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
    
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`)
    
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
    
5.  Open a Pull Request
    

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.