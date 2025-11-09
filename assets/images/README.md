# Assets / Images

Place your splash and icon images here.

- `splash_logo.png`: Use a clear PNG around 1200x1200 (or 1024x1024). This is referenced by the splash config `assets/images/splash_logo.png`.

- Android app icons: Use an app icon generator to create `mipmap-` folders (mipmap-mdpi, mipmap-hdpi, mipmap-xhdpi, etc.). Place those folders' contents into `android/app/src/main/res/` to replace the default Flutter icons (or copy the generated `mipmap-` folders into that `res` folder).

Notes:
- I cannot add binary images here. Add PNG files manually into this folder and then run:

  flutter pub get
  dart run flutter_native_splash:create

- After generating the native splash and adding icons, do a full rebuild (no hot reload):

  flutter clean
  flutter run
