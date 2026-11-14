import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/imaging/adjust.dart';
import 'package:lumen/imaging/processor.dart';

Uint8List solid(int w, int h, int r, int g, int b) {
  final out = Uint8List(w * h * 3);
  for (var i = 0; i < w * h; i++) {
    out[i * 3] = r;
    out[i * 3 + 1] = g;
    out[i * 3 + 2] = b;
  }
  return out;
}

/// A flat, hazy gradient with a blue cast: what Smart Enhance should fix.
Uint8List hazy(int w, int h) {
  final out = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = 70 + (x / w * 110).round(); // 70..180: flat histogram
      final i = (y * w + x) * 3;
      out[i] = v;
      out[i + 1] = v + 4;
      out[i + 2] = (v + 25).clamp(0, 255);
    }
  }
  return out;
}

void main() {
  group('tone curve', () {
    test('neutral settings are an identity map', () {
      final lut = toneCurve(const Adjustments(), 0);
      for (var i = 0; i < 256; i++) {
        expect(lut[i], i);
      }
    });

    test('exposure brightens, contrast spreads mid-tones', () {
      final bright = toneCurve(const Adjustments(exposure: 0.5), 0);
      expect(bright[100], greaterThan(100));
      final contrast = toneCurve(const Adjustments(contrast: 0.5), 0);
      expect(contrast[64], lessThan(64));
      expect(contrast[192], greaterThan(192));
    });

    test('levels stretch the black and white points', () {
      final lut = toneCurve(const Adjustments(levels: Levels([50, 50, 50], [200, 200, 200])), 0);
      expect(lut[50], 0);
      expect(lut[200], 255);
      expect(lut[125], closeTo(128, 2));
    });

    test('fade lifts blacks', () => expect(toneCurve(const Adjustments(fade: 1), 0)[0], greaterThan(20)));
  });

  group('applyAdjustments', () {
    test('neutral leaves pixels unchanged', () {
      final px = solid(4, 4, 10, 120, 240);
      applyAdjustments(px, 4, 4, const Adjustments());
      expect(px.sublist(0, 3), [10, 120, 240]);
    });

    test('saturation -1 makes grey', () {
      final px = solid(2, 2, 200, 50, 50);
      applyAdjustments(px, 2, 2, const Adjustments(saturation: -1));
      expect(px[0], px[1]);
      expect(px[1], px[2]);
    });

    test('warmth shifts red up and blue down', () {
      final px = solid(2, 2, 100, 100, 100);
      applyAdjustments(px, 2, 2, const Adjustments(warmth: 1));
      expect(px[0], greaterThan(100));
      expect(px[2], lessThan(100));
    });

    test('vignette darkens corners more than the centre', () {
      final px = solid(41, 41, 200, 200, 200);
      applyAdjustments(px, 41, 41, const Adjustments(vignette: 1));
      final corner = px[0];
      final centre = px[(20 * 41 + 20) * 3];
      expect(corner, lessThan(centre));
    });
  });

  group('Smart Enhance', () {
    test('finds a flat histogram and a blue cast and fixes both', () {
      const w = 200, h = 50;
      final px = hazy(w, h);
      final r = analyzeForEnhance(px, w, h);
      expect(r.adjustments.levels.black[0], greaterThan(60 - 1));
      expect(r.adjustments.levels.white[0], lessThanOrEqualTo(190));
      expect(r.adjustments.whiteBalance[2], lessThan(1)); // pull blue down
      expect(r.notes.join(' '), contains('contrast'));
      expect(r.notes.join(' '), contains('blue'));

      applyAdjustments(px, w, h, r.adjustments);
      var minV = 255, maxV = 0, blue = 0.0, red = 0.0;
      for (var i = 0; i < w * h; i++) {
        final v = px[i * 3 + 1];
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
        red += px[i * 3];
        blue += px[i * 3 + 2];
      }
      expect(maxV - minV, greaterThan(200)); // contrast restored
      expect((blue - red).abs() / (w * h), lessThan(12)); // cast mostly gone
    });

    test('a well balanced image gets only a light touch', () {
      const w = 64, h = 64;
      final px = Uint8List(w * h * 3);
      for (var i = 0; i < w * h; i++) {
        final v = (i * 255 / (w * h)).round();
        px[i * 3] = v;
        px[i * 3 + 1] = v;
        px[i * 3 + 2] = v;
      }
      final r = analyzeForEnhance(px, w, h);
      expect(r.adjustments.whiteBalance, everyElement(closeTo(1, 0.01)));
      expect(r.adjustments.exposure.abs(), lessThan(0.06));
    });
  });

  group('smartCrop', () {
    test('pads the subject and keeps it centred', () {
      final c = smartCrop(imageWidth: 1000, imageHeight: 800, left: 400, top: 300, width: 200, height: 200);
      expect(c.width, closeTo(248, 0.01));
      expect(c.left + c.width / 2, closeTo(500, 0.01));
      expect(c.top + c.height / 2, closeTo(400, 0.01));
    });

    test('respects the aspect ratio and stays inside the image', () {
      final c = smartCrop(imageWidth: 1000, imageHeight: 800, left: 0, top: 0, width: 300, height: 100, aspect: 4 / 5);
      expect(c.width / c.height, closeTo(0.8, 0.001));
      expect(c.left, 0);
      expect(c.top, 0);
      expect(c.left + c.width, lessThanOrEqualTo(1000));
      expect(c.top + c.height, lessThanOrEqualTo(800));
    });

    test('never exceeds the image for huge subjects', () {
      final c = smartCrop(imageWidth: 600, imageHeight: 400, left: 0, top: 0, width: 600, height: 400, aspect: 1);
      expect(c.width, lessThanOrEqualTo(600));
      expect(c.height, lessThanOrEqualTo(400));
      expect(c.width, c.height);
    });
  });

  test('every look keeps values in range', () {
    for (final p in presets.values) {
      for (var ch = 0; ch < 3; ch++) {
        final lut = toneCurve(p, ch);
        expect(lut.every((v) => v >= 0 && v <= 255), isTrue);
      }
    }
  });

  test('decode/encode round trip keeps size', () {
    final d = Decoded(solid(30, 20, 120, 60, 30), 30, 20);
    final jpg = encodeJpg(d);
    final back = decodeRgb(jpg);
    expect(back.width, 30);
    expect(back.height, 20);
    expect(back.rgb[0], closeTo(120, 8));
  });
}
