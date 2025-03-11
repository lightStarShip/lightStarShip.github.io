#!/bin/bash

# 定义变量
APP_NAME="theBigDipper.app"
DMG_NAME="theBigDipper_Installer.dmg"
TEMPDIR="/tmp/YourAppDMG"
VOLUME_NAME="theBigDipper Installer"
BACKGROUND_IMAGE="image/bg_img.png"  # 可选背景图路径

# 清理临时目录
rm -rf "${TEMPDIR}"
mkdir -p "${TEMPDIR}"

# 复制 .app 文件到临时目录
cp -R "${APP_NAME}" "${TEMPDIR}/"

# 创建 Applications 文件夹的快捷方式
ln -s "/Applications" "${TEMPDIR}/Applications"

# （可选）复制背景图到临时目录
if [ -f "${BACKGROUND_IMAGE}" ]; then
  cp "${BACKGROUND_IMAGE}" "${TEMPDIR}/.background.png"
fi

# 创建可读写的 DMG
hdiutil create -srcfolder "${TEMPDIR}" -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 200m "${DMG_NAME}.temp"

# 挂载 DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_NAME}.temp.dmg" | awk 'NR==1{print$1}')
MOUNT_PATH="/Volumes/${VOLUME_NAME}"

# （可选）设置窗口视图属性（图标位置、背景图）
if [ -f "${BACKGROUND_IMAGE}" ]; then
  echo '
  tell application "Finder"
    tell disk "'${VOLUME_NAME}'"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {400, 100, 1000, 500}
      set viewOptions to the icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 96
      set background picture of viewOptions to file ".background.png"
      set position of item "'${APP_NAME}'" of container window to {200, 200}
      set position of item "Applications" of container window to {500, 200}
      close
      open
      update without registering applications
      delay 2
    end tell
  end tell
  ' | osascript
fi

# 设置权限并卸载 DMG
chmod -Rf go-w "${MOUNT_PATH}"
sync
hdiutil detach "${DEVICE}"

# 压缩为最终只读 DMG
hdiutil convert "${DMG_NAME}.temp.dmg" -format UDBZ -o "${DMG_NAME}"

# 清理临时文件
rm -f "${DMG_NAME}.temp.dmg"


# 替换为你的开发者证书名称（钥匙串中的名称）
codesign --sign "Developer ID Installer: Yushian (Beijing) Technology Co., Ltd. (2XYK8RBB6M)" --timestamp YourApp_Installer.dmg
mv theBigDipper_Installer.dmg  theBigDipper.dmg
