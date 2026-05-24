# Expo

This package includes native Android and iOS code, so Expo Go cannot run it unless the package is included in Expo Go in the future.

Use an Expo development build:

```sh
npx expo prebuild
npx expo run:ios
npx expo run:android
```

The repo's `example/` app is configured as an Expo app that depends on the local package via `file:..`.
