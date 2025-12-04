# 📦 Final Build Guide
This document guides you through generating a production-ready Android APK for **Route Memory**.

## 1. Prepare for Release
Before building, ensure your app is ready for the public.

1. Remove Debug Banner:

    - Check `lib/main.dart`.

    - Ensure `debugShowCheckedModeBanner: false` is inside `MaterialApp`.

2. App Icon:

    - Ensure you have a launcher icon. If not, use the `flutter_launcher_icons` package to generate one.

3. App Name:

    - Verify the label in `android/app/src/main/AndroidManifest.xml`:
            
        ```      
        <application
            android:label="Route Memory" ... >
        ```

## 2. Digital Signing (Crucial for Android)
Android requires all apps to be digitally signed with a certificate before they can be installed.

**Step A: Generate a Keystore**

Open your terminal and run this command (Windows/Mac/Linux):

**For Windows (Powershell):**

    keytool -genkey -v -keystore C:\Users\YourUser\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload

**For Mac/Linux:**

    keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

- **Password:** Create a strong password (e.g., `routeMemory2025`). **Remember this!**

- **Questions:** Answer the questions (Name, Org, City, etc.).

- **Result:** This creates a file named `upload-keystore.jks`.

\
**Step B: Configure Gradle**

1. **Move the Keystore:**
Copy the `upload-keystore.jks` file you just created into the `android/app/` folder of your project.

2. **Create key.properties:**
Create a file named `key.properties` in the `android/` folder (not `android/app/`, just `android/`). Add this content:

        storePassword=routeMemory2025
        keyPassword=routeMemory2025
        keyAlias=upload
        storeFile=../app/upload-keystore.jks

3. **Update build.gradle.kts:**
**Open** `android/app/build.gradle.kts`.Find the `android { ... }` block and replace/update the `signingConfigs` and `buildTypes` sections to look like this:

        // ... inside android { ... }

        signingConfigs {
            create("release") {
                // Load the keystore.properties file here to avoid scope issues
                val keystoreFile = rootProject.file("key.properties")
                val props = Properties()

                if (keystoreFile.exists()) {
                    props.load(FileInputStream(keystoreFile))

                    keyAlias = props["keyAlias"] as String
                    keyPassword = props["keyPassword"] as String
                    storeFile = file(props["storeFile"] as String)
                    storePassword = props["storePassword"] as String
                } else {
                    println("⚠️ Warning: key.properties not found. Release build will fail signing.")
                }
            }
        }

        buildTypes {
            getByName("release") {
                isMinifyEnabled = true
                isShrinkResources = true
                proguardFiles(
                    getDefaultProguardFile("proguard-android.txt"),
                    "proguard-rules.pro"
                )
                signingConfig = signingConfigs.getByName("release")
            }
        }


## *3. Build the APK*
Now that signing is configured, generate the file.

1. **Clean the project:**

        flutter clean
        flutter pub get

2. **Build Command:** Run this in your terminal:

        flutter build apk --release

3. **Locate the File:**
Once the build finishes, your APK will be located here:

        build/app/outputs/flutter-apk/app-release.apk

## 4. Install & Test
To install this release version directly onto your connected phone:

    flutter install
