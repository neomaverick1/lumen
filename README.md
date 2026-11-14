# Lumen: on-device AI photo studio (Flutter + ML Kit)

A **Flutter** photo editor with **on-device AI**. Smart Enhance fixes a photo in one tap; **Google ML Kit** auto-tags your library for smart search, reads text from photos and finds objects for a one-tap smart crop. Nothing is uploaded: every model runs on the phone.

<p>
  <img src="docs/screenshots/01_library.png" width="180" alt="Library with AI tags">
  <img src="docs/screenshots/02_enhance_compare.png" width="180" alt="Smart Enhance with before/after">
  <img src="docs/screenshots/03_looks.png" width="180" alt="Looks">
  <img src="docs/screenshots/04_adjust.png" width="180" alt="Manual adjustments">
</p>
<p>
  <img src="docs/screenshots/05_tags.png" width="180" alt="Auto-tags">
  <img src="docs/screenshots/06_text_scan.png" width="180" alt="Text scan">
  <img src="docs/screenshots/07_objects.png" width="180" alt="Object detection">
  <img src="docs/screenshots/08_smart_crop.png" width="180" alt="Smart crop">
</p>

These screenshots are taken automatically on an **Android emulator in CI** while an integration test drives the app with the real ML Kit models ([`integration_test/screenshots_test.dart`](integration_test/screenshots_test.dart)).

## Try it

| Platform | How |
| --- | --- |
| **Android 7+** | Download `Lumen.apk` from the [latest release](https://github.com/neomaverick1/lumen/releases/latest). |
| **iPhone simulator** | Download `Lumen-iOS-Simulator.zip` from the same release, unzip and drag the app onto a booted simulator. |
| **Web (editing only)** | [neomaverick1.github.io/lumen](https://neomaverick1.github.io/lumen/). ML Kit is mobile-only, so the AI tools live in the phone apps. |

## Features

| Area | What it does |
| --- | --- |
| **Smart Enhance** | Reads the histogram and colour balance and fixes the photo in one tap: per-channel levels (0.5% / 99.5% percentiles) for flat or hazy shots, gray-world white balance for colour casts, an exposure nudge, and vibrance for dull colours. It tells you what it fixed. |
| **Before / after** | Tap or drag across the photo to compare the original with the edit. |
| **Looks** | Eight film-style presets (Vivid, Golden, Nordic, Noir, Matte, Drama, Pastel) with live thumbnails, layered on top of Smart Enhance. |
| **Adjust** | Exposure, contrast, saturation, warmth, highlights, shadows, vignette, fade. Tone work goes through 256-entry lookup tables, so full-resolution exports stay fast. |
| **Auto-tags + smart search** | ML Kit Image Labeling tags every photo on import; search "cat", "food" or "text" to find photos by what is in them. |
| **Text scan** | ML Kit Text Recognition finds every line, draws the boxes on the photo, and copies the text in one tap. |
| **Objects + smart crop** | ML Kit Object Detection boxes the objects; Smart crop frames the one you pick at 4:5 with breathing room, clamped to the photo. |
| **Export** | Renders at full resolution in a background isolate and opens the share sheet (save, send, post). |

## Architecture

```
lib/
  imaging/   adjust.dart (pure Dart: tone curves, colour, vignette, Smart Enhance analysis, presets, smart crop)
             processor.dart (decode, render and analyse in background isolates)
  ai/        AiEngine interface; ML Kit on Android/iOS, a web stub picked by conditional import
  data/      photo library, tags, smart search, temp files for ML Kit
  ui/        library grid, editor (Enhance / Looks / Adjust / AI tabs), compare view with overlay boxes
```

**Tests:** 16 unit and widget tests (tone curves, colour maths, Smart Enhance fixing a hazy, colour-cast image, smart crop geometry, JPEG round trip, library tagging and search with a fake AI engine), plus the on-device integration test that runs in CI on an Android emulator.

## Build it yourself

```bash
flutter pub get
flutter test
flutter run                     # on a phone or emulator for the AI tools
flutter build apk --release
```

## Stack

Flutter 3.50 · Dart · Google ML Kit (image labeling, text recognition, object detection) · image · isolates · integration_test on an Android emulator · GitHub Actions · GitHub Pages

Sample photos: "Chelsea the cat" (CC0, Stefan van der Walt), "Coffee" (CC0, Rachel Michetti), DSCOVR launch (public domain, SpaceX), Hubble eXtreme Deep Field (public domain, NASA), via scikit-image. The café menu is generated. Inter font under the SIL Open Font License. MIT licensed.
