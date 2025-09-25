#!/bin/bash

# Made to be executed on macOS (Github Actions runner or local machine)
# Made by github.com/johan-perso /// johanstick.fr
# For Flutter app. Build.sh v1.1.0 (2025-09-25)

DATE=$(date +"%Y-%m-%d")
PROJECT_UPPERCASE="eScive"
PROJECT_LOWERCASE="escive"

if [[ -f ".env" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]] && continue
        [[ "$line" == *=* ]] && export "$line"
    done < ".env"
fi

to_ipa() {
    if [ "$#" -lt 1 ]; then
        echo "❌ Please enter a file name."
        return 1
    fi

    local file="$1"
    local base_name

    if [ "${file: -4}" != ".app" ]; then
        echo "❌ The file extension is not .app"
        return 1
    fi

    if [ ! -e "$file" ]; then
        echo "❌ File does not exist: $file"
        return 1
    fi

    echo "!!! Converting .app to .ipa..."

    mkdir -p Payload
    cp -r "$file" Payload/

    base_name=$(basename "$file" .app)
    if [ "$(basename "$file")" != "$(basename "$file" .app).app" ]; then
        mv "Payload/$(basename "$file")" "Payload/$(basename "$file" .app).app"
    fi

    zip -r "${base_name}.ipa" Payload > /dev/null 2>&1
    rm -rf Payload

    echo "✅ IPA created: ${base_name}.ipa"
    return 0
}

make_request() {
    local url="$1"
    local method="$2"
    local content_type="$3"
    local data="$4"
    local description="$5"

    echo "!!! $description..."

    if [ -z "$BASE_URL" ] || [ -z "$url" ] || [ -z "$API_KEY" ]; then
        echo "⚠️  Request skipped - BASE_URL, API_KEY or url not set"
        echo "   Current values:"
        echo "   - BASE_URL: ${BASE_URL:-'(not set)'}"
        echo "   - API_KEY: ${API_KEY:0:10}... (showing first 10 chars)"
        echo "   - URL endpoint: ${url:-'(not set)'}"
        return 0
    fi

    # Depending on content type, adjust curl command
    local response
    if [ "$content_type" = "multipart/form-data" ]; then
        # For file uploads
        response=$(curl -s -w "\n%{http_code}" \
            -X "$method" \
            -H "Authorization: $API_KEY" \
            $data \
            "$BASE_URL/$url")
    else
        # For request with JSON body or other data
        response=$(curl -s -w "\n%{http_code}" \
            -X "$method" \
            -H "Authorization: $API_KEY" \
            -H "Content-Type: $content_type" \
            -d "$data" \
            "$BASE_URL/$url")
    fi

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 200 ]; then
        echo "✅ $description completed successfully"
        return 0
    else
        echo "❌ Failed: $description"
        echo "Status code: $http_code"
        echo "Response: $body"
        return 1
    fi
}

upload_file() {
    local file_path="$1"
    local field_name="$2"
    local filename=$(basename "$file_path")
    if [ ! -f "$file_path" ]; then
        echo "❌ File not found: $file_path"
        return 1
    fi

    make_request "api/receive" "POST" "multipart/form-data" "-F $field_name=@$file_path" "Uploading $filename as $field_name"
    local result=$?
}

upload_json() {
    local json_data="$1"
    local endpoint="$2"
    local description="${3:-Uploading JSON data}"

    if [ -z "$json_data" ]; then
        echo "❌ JSON data is empty"
        return 1
    fi

    local result
    make_request "$endpoint" "POST" "application/json" "$json_data" "$description"
    result=$?

    return $result
}

echo "================="
FULL_VERSION=$(grep 'version:' pubspec.yaml | awk '{print $2}') # 1.0.0+1
echo "Full version: $FULL_VERSION"
VERSION_CODE=$(echo $FULL_VERSION | cut -d '+' -f 1) # 1.0.0
echo "Version code: $VERSION_CODE"
BUILD_NUMBER=$(echo $FULL_VERSION | cut -d '+' -f 2) # 1
echo "Build number: $BUILD_NUMBER"
echo ""

# 1/3 Build iOS - IPA
echo "================= 1/3 - iOS - IPA file"
flutter build ios --release --no-codesign
if [ $? -ne 0 ]; then
    echo "❌ Build for iOS failed"
    exit 1
fi

to_ipa build/ios/iphoneos/Runner.app
rm build/ios/iphoneos/Runner.app
if [ -f "Runner.ipa" ]; then
    mkdir -p build
    mv Runner.ipa build/$PROJECT_UPPERCASE-ios-$DATE-store.ipa
else
    echo "❌ Runner.ipa not found after conversion"
    exit 1
fi
upload_file "build/$PROJECT_UPPERCASE-ios-$DATE-store.ipa" "$PROJECT_LOWERCASE/ios/$VERSION_CODE/store.ipa"

# Generate JSON objects for AltStore
PRIVACY_JSON=$(/usr/libexec/PlistBuddy -c 'Print' build/ios/iphoneos/Runner.app/Info.plist 2>/dev/null | \
grep 'UsageDescription' | \
sed 's/^ *//' | \
sed 's/ = /|/' | \
jq -R -s 'split("\n")[:-1] | map(split("|") | {(.[0]): .[1]}) | add')

ENTITLEMENTS_JSON=$(plutil -convert json -o - ios/Runner/Runner.entitlements 2>/dev/null | jq 'keys | map(select(. | test("(application-identifier|team-identifier)") | not))')
if [[ -z "$ENTITLEMENTS_JSON" ]]; then
    ENTITLEMENTS_JSON='[]'
fi

APP_PERMISSIONS_JSON=$(echo '{}' | jq --argjson privacy "$PRIVACY_JSON" --argjson entitlements "$ENTITLEMENTS_JSON" '{
  appPermissions: {
    entitlements: $entitlements,
    privacy: $privacy
  },
  buildVersion: "'$BUILD_NUMBER'",
  version: "'$VERSION_CODE'",
}')
echo "Generated JSON for 'appPermissions':"
echo "$APP_PERMISSIONS_JSON" | jq '.'
upload_json "$APP_PERMISSIONS_JSON" "api/altstoreJson?project=$PROJECT_LOWERCASE" "Uploading JSON for AltStore"

# 2/3 Build Android - APK
echo "================= 2/3 - Android - APK file"
flutter build apk --release
if [ $? -ne 0 ]; then
    echo "❌ Build for Android (APK) failed"
    exit 1
fi
mv build/app/outputs/flutter-apk/app-release.apk build/
rm -f build/$PROJECT_UPPERCASE-android-$DATE-store.apk
mv build/app-release.apk build/$PROJECT_UPPERCASE-android-$DATE-store.apk
upload_file "build/$PROJECT_UPPERCASE-android-$DATE-store.apk" "$PROJECT_LOWERCASE/android/$VERSION_CODE/store.apk"

# 3/3 Build Android - AAB (for Play Store)
echo "================= 3/3 - Android - AAB file"
flutter build appbundle --release
if [ $? -ne 0 ]; then
    echo "❌ Build for Android (AAB) failed"
    exit 1
fi
mv build/app/outputs/bundle/release/app-release.aab build/
rm -f build/$PROJECT_UPPERCASE-android-$DATE-store.aab
mv build/app-release.aab build/$PROJECT_UPPERCASE-android-$DATE-store.aab

echo "================= Files paths:"
echo "iOS (IPA):        $(pwd)/build/$PROJECT_UPPERCASE-ios-$DATE-store.ipa"
echo "Android (AAB):    $(pwd)/build/$PROJECT_UPPERCASE-android-$DATE-store.aab"
echo "Android (APK):    $(pwd)/build/$PROJECT_UPPERCASE-android-$DATE-store.apk"
echo "Folder:           $(pwd)/build"
echo "================="

echo "!!!!! WEB Support isn't built automatically !!!!!"