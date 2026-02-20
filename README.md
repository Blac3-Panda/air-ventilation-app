<<<<<<< HEAD
`<a href="https://flutter.dev/">`

<h1 align="center">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://storage.googleapis.com/cms-storage-bucket/6e19fee6b47b36ca613f.png">
      <img alt="Flutter" src="https://storage.googleapis.com/cms-storage-bucket/c823e53b3a1a7b0d36a9.png">
    </picture>
  </h1>
</a>

[![Flutter CI Status](https://flutter-dashboard.appspot.com/api/public/build-status-badge?repo=flutter)](https://flutter-dashboard.appspot.com/#/build?repo=flutter)
[Discord badge][Discord instructions]
[Twitter handle][Twitter badge]
[BlueSky badge][BlueSky handle]
[![codecov](https://codecov.io/gh/flutter/flutter/branch/master/graph/badge.svg?token=11yDrJU2M2)](https://codecov.io/gh/flutter/flutter)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/5631/badge)](https://bestpractices.coreinfrastructure.org/projects/5631)
[![SLSA 1](https://slsa.dev/images/gh-badge-level1.svg)](https://slsa.dev)

Flutter is Google's SDK for crafting beautiful, fast user experiences for
mobile, web, and desktop from a single codebase. Flutter works with existing
code, is used by developers and organizations around the world, and is free and
open source.

## Documentation

* [Install Flutter](https://docs.flutter.dev/get-started)
* [Flutter documentation](https://docs.flutter.dev)
* [Development wiki](./docs/README.md)
* [Contributing to Flutter](https://github.com/flutter/flutter/blob/main/CONTRIBUTING.md)

For release and other announcements, join the
[flutter-announce](https://groups.google.com/g/flutter-announce)
mailing list. Our documentation also tracks [breaking
changes](https://docs.flutter.dev/release/breaking-changes) across releases.

## Terms of service

The Flutter tool may occasionally download resources from Google servers. By
downloading or using the Flutter SDK, you agree to the Google Terms of Service:
https://policies.google.com/terms

For example, when installed from GitHub (as opposed to from a prepackaged
archive), the Flutter tool will download the Dart SDK from Google servers
immediately when first run, as it is used to execute the `flutter` tool itself.
This will also occur when Flutter is upgraded (e.g. by running the `flutter upgrade` command).

## About Flutter

We think Flutter will help you create beautiful, fast apps, with a productive,
extensible and open development model, whether you're targeting iOS or Android,
web, Windows, macOS, Linux or embedding it as the UI toolkit for a platform of
your choice.

### Beautiful user experiences

We want to enable designers to deliver their full creative vision without being
forced to water it down due to limitations of the underlying framework.
Flutter's [layered architecture][layered architecture] gives you control over every pixel on the
screen and its powerful compositing capabilities let you overlay and animate
graphics, video, text, and controls without limitation. Flutter includes a full
[set of widgets][widget catalog] that deliver pixel-perfect experiences whether
you're building for iOS ([Cupertino][Cupertino]) or other platforms ([Material][Material]), along with
support for customizing or creating entirely new visual components.

<p align="center"><img src="https://github.com/flutter/website/blob/main/site/web/assets/images/docs/homepage/reflectly-hero-600px.png?raw=true" alt="Reflectly hero image"></p>

### Fast results

Flutter is fast. It's powered by hardware-accelerated 2D graphics
libraries like [Skia][Skia] (which underpins Chrome and Android) and
[Impeller][Impeller]. We architected Flutter to
support glitch-free, jank-free graphics at the native speed of your device.

Flutter code is powered by the world-class [Dart programming language][Dart programming language], which enables
compilation to 32-bit and 64-bit ARM machine code for iOS and Android,
JavaScript and WebAssembly for the web, as well as Intel x64 and ARM
for desktop devices.

<p align="center"><img src="https://github.com/flutter/website/blob/main/site/web/assets/images/docs/homepage/dart-diagram-small.png?raw=true" alt="Dart diagram"></p>

### Productive development

Flutter offers [stateful hot reload][Hot reload], allowing you to make changes to your code
and see the results instantly without restarting your app or losing its state.

[Hot reload animation][Hot reload]

### Extensible and open model

Flutter works with any development tool (or none at all), and also includes
editor plug-ins for both [Visual Studio Code][Visual Studio Code] and [IntelliJ / Android Studio][IntelliJ / Android Studio].
Flutter provides [tens of thousands of packages][Flutter packages] to speed your
development, regardless of your target platform. And accessing other native code
is easy, with support for both FFI ([on Android][Android FFI], [on iOS][iOS FFI],
[on macOS][macOS FFI], and [on Windows][Windows FFI]) as well as
[platform-specific APIs][platform channels].

Flutter is a fully open-source project, and we welcome contributions.
Information on how to get started can be found in our
[contributor guide](CONTRIBUTING.md).

=======

[flutter.dev]: https://flutter.dev
[Discord instructions]: ./docs/contributing/Chat.md
[Discord badge]: https://img.shields.io/discord/608014603317936148?logo=discord
[Twitter handle]: https://img.shields.io/twitter/follow/flutterdev.svg?style=social&label=Follow
[Twitter badge]: https://twitter.com/intent/follow?screen_name=flutterdev
[BlueSky badge]: https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff&label=Follow%20me%20on&color=0285FF
[BlueSky handle]: https://bsky.app/profile/flutter.dev
[layered architecture]: https://docs.flutter.dev/resources/inside-flutter
[architectural overview]: https://docs.flutter.dev/resources/architectural-overview
[widget catalog]: https://docs.flutter.dev/ui/widgets
[Cupertino]: https://docs.flutter.dev/ui/widgets/cupertino
[Material]: https://docs.flutter.dev/ui/widgets/material
[Skia]: https://skia.org/
[Dart programming language]: https://dart.dev/
[Hot reload animation]: https://github.com/flutter/website/blob/main/site/web/assets/images/docs/tools/android-studio/hot-reload.gif?raw=true
[Hot reload]: https://docs.flutter.dev/tools/hot-reload
[Visual Studio Code]: https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter
[IntelliJ / Android Studio]: https://plugins.jetbrains.com/plugin/9212-flutter
[Flutter packages]: https://pub.dev/flutter
[Android FFI]: https://docs.flutter.dev/platform-integration/android/c-interop
[iOS FFI]: https://docs.flutter.dev/platform-integration/ios/c-interop
[macOS FFI]: https://docs.flutter.dev/platform-integration/macos/c-interop
[Windows FFI]: https://docs.flutter.dev/platform-integration/windows/building#integrating-with-windows
[platform channels]: https://docs.flutter.dev/platform-integration/platform-channels
[interop example]: https://github.com/flutter/flutter/tree/main/examples/platform_channel
[Impeller]: https://docs.flutter.dev/perf/impeller
# Air Ventilation App

## 📌 프로젝트 개요

실시간 외부 대기질 데이터를 활용하여 사용자에게 적절한 환기 시점을 안내하는 모바일 애플리케이션입니다.

단순 정보 제공이 아닌, 사용자의 행동(환기 여부)을 결정하는 기준을 제공하는 것을 목표로 개발했습니다.

---

## 🛠 기술 스택

- Flutter
- REST API (공공 대기질 API)
- JSON Parsing
- Async / Await
- 상태관리 (Provider)
- HTTP 통신 (http 패키지)

---

## 🏗 앱 구조

1. 외부 API 호출 (비동기 처리)
2. JSON 데이터 파싱
3. 환기 가능 여부 판단 로직 적용
4. 상태 업데이트 후 UI 반영
5. 예외 상황(네트워크 오류, API 에러) 처리

---

## 🔥 주요 기능

- 실시간 대기질 데이터 조회
- 위치 기반 데이터 반영
- 환기 적정 여부 자동 판단
- 로딩 상태 및 에러 UI 처리

---

## 🧩 트러블슈팅 경험

- API 호출 시 403 에러 발생 → 인증키 인코딩 문제 해결
- 비동기 처리 중 setState 호출 타이밍 오류 해결
- 상태관리 구조 개선으로 UI 리렌더링 문제 해결

---

## 📈 배운 점

- 모바일 앱에서의 API 통신 구조 이해
- 비동기 처리와 상태관리의 중요성 체감
- 실제 서비스 운영 시 광고 및 수익화 구조 고민

>>>>>>> 196c53bee96ec9ee29baa5d002d598200425543c
>>>>>>>
>>>>>>
>>>>>
>>>>
>>>
>>
