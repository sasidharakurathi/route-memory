# Route Memory 📍


A GPS tracking and navigation application built with Flutter. Route Memory allows users to record their journeys with high precision, visualize their history on interactive maps, and retrace their steps using smart navigation logic.
---
## ✨ Features
### 🛰️ High-Fidelity Tracking

*   **Real-time GPS Recording:** Captures location data every second using high-performance foreground services.
*   **Smart Filtering:** Automatically filters out GPS noise and jitter when stationary (< 0.5m movement).
*   **Background Capable:** Optimized to keep recording even when the screen is off.

### 🗺️ Intelligent Navigation
*   **Breadcrumb Guidance:** Retrace your exact steps with a "Ghost Path" visualizer (Blue Line).
*   **Hybrid Routing:** Automatically switches between "Off-road" mode (direct line) and "Road-snap" mode (using OSRM API) depending on your distance from the recorded path (> 40m deviation triggers smart routing).
*   **Turn-by-Turn HUD:** Heads-up display showing distance remaining, estimated time of arrival (ETA), and dynamic heading indicators.

### 💾 Robust Data Management
*   **Local Persistence:** Routes are stored locally using **Hive** (NoSQL), ensuring privacy and offline access.
*   **Route Management:** Rename, delete single routes, or batch-delete history logs via long-press selection.
*   **Checkpoint System:** Drop custom markers (pins) during recording to flag interesting spots.

### 🎨 Quality of Service (QoS) UI
*   **Immersive Design:** Full-screen map interface with glassmorphism overlays.
*   **Adaptive Controls:** Ergonomic button placement for one-handed usage.
*   **Dynamic Theming:** Navigation bar and status bar adaptation for a seamless feel.

### 🛠️ Tech Stack
*   **Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **State Management:** [Riverpod](https://riverpod.dev/)
*   **Maps:** [flutter\_map](https://pub.dev/packages/flutter_map) (OpenStreetMap)
*   **Database:** [Hive](https://github.com/hivedb/docs)
*   **Location:** [geolocator](https://pub.dev/packages/geolocator)
*   **Routing API:** OSRM (Open Source Routing Machine) public demo server.

---
## 🚀 Getting Started
### Prerequisites

*   Flutter SDK (3.0.0 or higher)
*   Android Studio / VS Code
*   A physical Android device (recommended for GPS testing). _Emulators may not simulate GPS movement correctly._
---
### Installation
1. **Clone the repository**
```bash
git clone https://github.com/sasidharakurathi/route-memory.git
```
2.  **Install dependencies:**
```bash
cd route-memory
flutter pub get
```
3.  **Run the app:**
```bash
flutter run
```
---
### 📱 Permissions

This app requires location permissions to function.
**Android:** Ensure `android/app/src/main/AndroidManifest.xml` includes:
```bash
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```
---
## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
1.  Fork the project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)   
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request
---
## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

