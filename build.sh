#!/bin/bash

DATE=$(date +"%Y-%m-%d")

# Release Android - APK
echo "================= 1/3 - Android (APK)"
flutter build apk --release
mv build/app/outputs/flutter-apk/app-release.apk build/
rm -f build/eScive-android-$DATE-store.apk
mv build/app-release.apk build/eScive-android-$DATE-store.apk

# Release Android - AAB
echo "================= 2/3 - Android (AAB)"
flutter build appbundle --release
mv build/app/outputs/bundle/release/app-release.aab build/
rm -f build/eScive-android-$DATE-store.aab
mv build/app-release.aab build/eScive-android-$DATE-store.aab

# Release iOS - IPA
echo "================= 3/3 - iOS (IPA)"
echo "Skipping build on iOS"
# flutter build ios --release
# sh ./utils/toipa.sh build/ios/iphoneos/Runner.app
# mv build/ios/iphoneos/Runner.ipa build/
# rm -f build/eScive-ios-$DATE-store.ipa
# mv build/Runner.ipa build/eScive-ios-$DATE-store.ipa

echo "================= Files paths:"
echo "iOS (IPA):        $(pwd)/build/eScive-ios-$DATE-store.ipa"
echo "Android (AAB):    $(pwd)/build/eScive-android-$DATE-store.aab"
echo "Android (APK):    $(pwd)/build/eScive-android-$DATE-store.apk"
echo "Folder:                 $(pwd)/build"
echo "================="