#!/bin/bash

appName=sample

# remove any existing code
rm -rf $appName

# create a sample application
flutter create --org com.microblink -a kotlin $appName

# enter into demo project folder
pushd $appName

IS_LOCAL_BUILD=false || exit 1
if [ "$IS_LOCAL_BUILD" = true ]; then
  # add blinkid_flutter dependency with local path to pubspec.yaml
  perl -i~ -pe "BEGIN{$/ = undef;} s/dependencies:\n  flutter:\n    sdk: flutter/dependencies:\n  flutter:\n    sdk: flutter\n  blinkid_flutter:\n    path: ..\/BlinkID\n  image_picker: 1.1.2/" pubspec.yaml
  echo "Using blinkid_flutter from this repo instead from flutter pub"
else
  # add blinkid_flutter dependency to pubspec.yaml
  perl -i~ -pe "BEGIN{$/ = undef;} s/dependencies:\n  flutter:\n    sdk: flutter/dependencies:\n  flutter:\n    sdk: flutter\n  blinkid_flutter:\n  image_picker: 1.1.2/" pubspec.yaml
  echo "Using blinkid_flutter from flutter pub"
fi

# get and install the dependencies
flutter pub get

# go to the android project folder
pushd android

# The BlinkID SDK uses minSdk 24. Replace 'minSdk = flutter.minSdkVersion' with 'minSdk = 24' in app/build.gradle.kts
sed -i '' 's/minSdk = flutter\.minSdkVersion/minSdk = 24/' app/build.gradle.kts

# Kotlin 2.3.x removes the kotlinOptions DSL. Replace it with tasks.withType<KotlinCompile> block.
perl -i'' -0pe 's/\n\n    kotlinOptions \{\n        jvmTarget = JavaVersion\.VERSION_17\.toString\(\)\n    \}//' app/build.gradle.kts
perl -i'' -0pe 's/(\nandroid \{)/\ntasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {\n    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)\n}$1/' app/build.gradle.kts

# Update AGP and KGP versions in settings.gradle.kts
# Note: AGP 9.0 is NOT supported by Flutter 3.41.x (requires Flutter 3.44.0+).
# Use AGP 8.9.1 which is the latest compatible version.
sed -i '' 's/id("com.android.application") version "[^"]*" apply false/id("com.android.application") version "8.9.1" apply false/' settings.gradle.kts
sed -i '' 's/id("org.jetbrains.kotlin.android") version "[^"]*" apply false/id("org.jetbrains.kotlin.android") version "2.3.20" apply false/' settings.gradle.kts

# AGP 8.9.1 works with Gradle 8.11.1+. Update the Gradle wrapper distribution URL.
sed -i '' 's|distributionUrl=.*|distributionUrl=https\\://services.gradle.org/distributions/gradle-8.11.1-bin.zip|' gradle/wrapper/gradle-wrapper.properties

# go to flutter root project
popd

# go to the ios project folder
pushd ios

# force minimal iOS version to iOS 16.0 as the BlinkID SDK requires it
sed -i '' '/<key>MinimumOSVersion<\/key>/{
n
s/<string>12\.0<\/string>/<string>16.0<\/string>/
}' Flutter/AppFrameworkInfo.plist

# Xcode project override
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*/IPHONEOS_DEPLOYMENT_TARGET = 16.0/' Runner.xcodeproj/project.pbxproj

# xcconfig override - append since Flutter-generated xcconfigs only contain an #include and have no existing entry to replace
echo "IPHONEOS_DEPLOYMENT_TARGET=16.0" >> Flutter/Debug.xcconfig
echo "IPHONEOS_DEPLOYMENT_TARGET=16.0" >> Flutter/Release.xcconfig

# add the camera and photo usage descriptions into Info.plist as the BlinkID SDK requires it.
# Use '^<dict>$' to match only the root-level <dict> tag (no indentation), avoiding
# insertion into nested dicts (UIApplicationSceneManifest, UISceneConfigurations, etc.).
sed -i '' '/^<dict>$/a\
\	<key>NSCameraUsageDescription</key>\
\	<string>Enable the camera usage for BlinkID default UX scanning</string>\
\	<key>NSPhotoLibraryUsageDescription</key>\
\	<string>Enable photo gallery usage for BlinkID DirectAPI scanning</string>\
' Runner/Info.plist

# update the config for iOS as the minimum target has been raised
flutter build ios --config-only

# go to flutter root project
popd

# copy the BlinkID sample app implementation files
cp ../sample_files/main.dart lib/
cp ../sample_files/blinkid_result_builder.dart lib/

echo ""
echo "Go to Flutter project folder: cd $appName"
echo "To run on Android type: flutter run"
echo "To run on iOS:
1. Open $appName/ios/Runner.xcodeproj
2. Set your development team
3. Press run"
