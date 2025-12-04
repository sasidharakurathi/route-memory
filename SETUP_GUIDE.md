# 🛠️ Project Setup Guide
This document provides step-by-step instructions to set up the Route Memory development environment, configure Firebase, and run the application on an Android device.

## 1. Prerequisites

Before you begin, ensure you have the following installed:
- **Flutter SDK**: Version 3.0.0 or higher. (Install Guide)
- **Dart SDK**: Included with Flutter.
- **IDE**: VS Code (recommended) or Android Studio.
- **Git**: For version control.
- **Android Device**: A physical Android phone is highly recommended because simulators often fail to emulate GPS movement and background services correctly.

## 2. Clone & Install Dependencies
1. Clone the Repository:

    ```
    git clone https://github.com/sasidharakurathi/route-memory.git
    cd route-memory
    ```

2. Install Flutter Packages:
    
    ```    
    flutter pub get
    ```

## 3. Firebase Configuration (Critical Step)

This project uses Firebase for Authentication and Database. You must provide your own Firebase project configuration.

1. **Create a Project:**
    - Go to the [Firebase Console](https://console.firebase.google.com/).
    - Click **Add Project** and name it `route-memory`.

2. **Enable Authentication:**
    - Go to **Build > Authentication**.
    - Click **Get Started**.
    - Enable **Email/Password** provider.
    - (Optional) Enable **Anonymous** provider.

3. **Create Firestore Database:**
    - Go to **Build > Firestore Database**.
    - Click **Create Database**.
    - Start in **Test Mode** (or Production Mode, we will update rules later).
    - Select a location close to you.

4. **Register Android App:**
    - Click the **Settings Gear > Project Settings**.
    - Scroll down to "Your apps" and click the **Android** icon.
    - **Package Name:** `com.sasidharakurathi.routememory` (Must match the `applicationId` in `android/app/build.gradle`).
    - **Debug Signing Certificate SHA-1**: Run `cd android && ./gradlew signingReport` to find this (optional for Email auth, required for Google Sign-in).
    - Click **Register App**.

5. Download Config File:
    - Download the `google-services.json` file.
    - Move this file into your project at: `android/app/google-services.json`.

## 4. Android Specific Configuration

To ensure background tracking works, verify the AndroidManifest.xml setup.

1. **Open Manifest:** `android/app/src/main/AndroidManifest.xml`

2. Verify Permissions:Ensure these lines exist inside the `<manifest>` tag:
    ```
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.INTERNET" />
    ```
3. Verify Service Declaration:Ensure this is inside the `<application>` tag (this allows the background tracker to survive app minimization):

    ```
    <service    
        android:name="com.baseflow.geolocator.GeolocatorLocationService"    
        android:enabled="true"    
        android:exported="true"    
        android:foregroundServiceType="location" />
    ```

## 5. Building & Running

1. **Connect your Device:** Enable "USB Debugging" on your Android phone and connect it via USB.

2. **Run the App:**

    ```
    flutter run
    ```

3. **Build the App**

    ```
    flutter build apk --release
    ```