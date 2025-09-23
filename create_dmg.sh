#!/usr/bin/env bash
set -euo pipefail

# ========= 基础路径：以脚本所在目录为准 =========
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

APP_NAME="theBigDipper.app"
APP_PATH="$SCRIPT_DIR/source/$APP_NAME"

DMG_NAME="theBigDipper.dmg"
DMG_PATH="$SCRIPT_DIR/$DMG_NAME"

ZIP_PATH="$SCRIPT_DIR/theBigDipper.zip"

# 证书 & Notary（使用 Keychain Profile）
DEV_ID_APP="${DEV_ID_APP:-Developer ID Application: Yushian (Beijing) Technology Co., Ltd.}"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary-profile}"
ENTITLEMENTS="${ENTITLEMENTS:-}"   # 如有：export ENTITLEMENTS=/path/to/entitlements.plist

# ========= 小工具：签名一个目标 =========
sign_one() {
  local target="$1"
  local cmd=(codesign --force --verify --verbose --timestamp --options runtime --sign "$DEV_ID_APP")
  [[ -n "$ENTITLEMENTS" && -f "$ENTITLEMENTS" ]] && cmd+=(--entitlements "$ENTITLEMENTS")
  echo "==> Signing: $target"
  "${cmd[@]}" "$target"
}

# ========= 0. 基本校验 =========
[[ -d "$SCRIPT_DIR/source" ]] || { echo "❌ 缺少目录: $SCRIPT_DIR/source"; exit 1; }
[[ -e "$APP_PATH" ]] || { echo "❌ 找不到 app: $APP_PATH"; exit 1; }

# ========= 1. 逐层签名 =========
echo "==> Signing nested items for: $APP_PATH"

# Frameworks
if [[ -d "$APP_PATH/Contents/Frameworks" ]]; then
  find "$APP_PATH/Contents/Frameworks" -maxdepth 1 -type d -name "*.framework" -print0 | while IFS= read -r -d '' fw; do
    sign_one "$fw"
  done
  find "$APP_PATH/Contents/Frameworks" -type f -print0 | while IFS= read -r -d '' f; do
    if file "$f" | grep -q 'Mach-O'; then sign_one "$f"; fi
  done
fi

# PlugIns / XPCServices / Helpers
for sub in "Contents/PlugIns" "Contents/XPCServices" "Contents/Helpers"; do
  if [[ -d "$APP_PATH/$sub" ]]; then
    find "$APP_PATH/$sub" -maxdepth 2 -type d \( -name "*.app" -o -name "*.bundle" -o -name "*.xpc" \) -print0 | while IFS= read -r -d '' b; do
      sign_one "$b"
    done
    find "$APP_PATH/$sub" -type f -print0 | while IFS= read -r -d '' f; do
      if file "$f" | grep -q 'Mach-O'; then sign_one "$f"; fi
    done
  fi
done

# 主 app
sign_one "$APP_PATH"

# 验签（spctl 未公证会提示 Unnotarized，属正常）
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH" || true
codesign -dv --verbose=4 "$APP_PATH" | grep -i 'flags\|runtime' || true

# ========= 2. 公证 .app =========
echo "==> Zipping app to: $ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Submitting .app for notarization (profile: $NOTARY_PROFILE) ..."
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait    # ⚠️ 不再使用 --output-format text

echo "==> Stapling .app ..."
xcrun stapler staple "$APP_PATH"

# ========= 3. 打包 DMG（使用 create-dmg） =========
echo "==> Creating DMG at: $DMG_PATH"

if [[ -x "$SCRIPT_DIR/../../create-dmg" ]]; then
  CREATE_DMG="$SCRIPT_DIR/../../create-dmg"
elif [[ -x "$SCRIPT_DIR/../../../../bin/create-dmg" ]]; then
  CREATE_DMG="$SCRIPT_DIR/../../../../bin/create-dmg"
elif command -v create-dmg >/dev/null 2>&1; then
  CREATE_DMG="$(command -v create-dmg)"
else
  echo "❌ 未找到 create-dmg，可通过 'brew install create-dmg' 安装"
  exit 1
fi

[[ -f "$DMG_PATH" ]] && rm -f "$DMG_PATH"

"$CREATE_DMG" \
  --volname "theBigDipper" \
  --volicon "$SCRIPT_DIR/icon.png" \
  --background "$SCRIPT_DIR/installer_bk.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "$APP_NAME" 200 190 \
  --hide-extension "$APP_NAME" \
  --app-drop-link 600 185 \
  "$DMG_PATH" \
  "$SCRIPT_DIR/source/"

# ========= 4. 公证 .dmg =========
echo "==> Submitting .dmg for notarization (profile: $NOTARY_PROFILE) ..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait    # ⚠️ 不再使用 --output-format text

echo "==> Stapling .dmg ..."
xcrun stapler staple "$DMG_PATH"


# ========= 5. Gatekeeper 验证 =========
echo "==> Verifying final DMG with spctl ..."
spctl --assess --type open --verbose "$DMG_PATH" || true

echo "==> Verifying stapled app inside DMG ..."
hdiutil attach "$DMG_PATH" -nobrowse -quiet -mountpoint /tmp/theBigDipper_mnt
spctl --assess --type execute --verbose "/tmp/theBigDipper_mnt/$APP_NAME" || true
hdiutil detach /tmp/theBigDipper_mnt -quiet


echo "🎉 Done. Final DMG: $DMG_PATH"
