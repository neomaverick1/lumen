import 'dart:math' as math;
import 'dart:typed_data';

/// Photo adjustments. Every value is 0 when neutral; most range -1..1.
class Adjustments {
  const Adjustments({
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.vignette = 0,
    this.fade = 0,
    this.levels = const Levels.identity(),
    this.whiteBalance = const [1, 1, 1],
  });

  final double exposure;
  final double contrast;
  final double saturation;
  final double warmth;
  final double highlights;
  final double shadows;
  final double vignette;
  final double fade;

  /// Per-channel black/white points found by Smart Enhance.
  final Levels levels;

  /// Per-channel gains (gray-world white balance).
  final List<double> whiteBalance;

  bool get isNeutral =>
      exposure == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      warmth == 0 &&
      highlights == 0 &&
      shadows == 0 &&
      vignette == 0 &&
      fade == 0 &&
      levels.isIdentity &&
      whiteBalance.every((g) => g == 1);

  Adjustments copyWith({
    double? exposure,
    double? contrast,
    double? saturation,
    double? warmth,
    double? highlights,
    double? shadows,
    double? vignette,
    double? fade,
    Levels? levels,
    List<double>? whiteBalance,
  }) => Adjustments(
    exposure: exposure ?? this.exposure,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    warmth: warmth ?? this.warmth,
    highlights: highlights ?? this.highlights,
    shadows: shadows ?? this.shadows,
    vignette: vignette ?? this.vignette,
    fade: fade ?? this.fade,
    levels: levels ?? this.levels,
    whiteBalance: whiteBalance ?? this.whiteBalance,
  );

  /// Layers a preset (or user tweaks) on top of these settings.
  Adjustments plus(Adjustments o) => copyWith(
    exposure: (exposure + o.exposure).clamp(-1, 1),
    contrast: (contrast + o.contrast).clamp(-1, 1),
    saturation: (saturation + o.saturation).clamp(-1, 1),
    warmth: (warmth + o.warmth).clamp(-1, 1),
    highlights: (highlights + o.highlights).clamp(-1, 1),
    shadows: (shadows + o.shadows).clamp(-1, 1),
    vignette: (vignette + o.vignette).clamp(0, 1),
    fade: (fade + o.fade).clamp(0, 1),
  );
}

class Levels {
  const Levels(this.black, this.white);
  const Levels.identity() : black = const [0, 0, 0], white = const [255, 255, 255];
  final List<int> black;
  final List<int> white;
  bool get isIdentity => black.every((b) => b == 0) && white.every((w) => w == 255);
}

/// Builds the 256-entry tone lookup table for one channel (levels, exposure, contrast, shadows,
/// highlights and fade). Doing tone work through a LUT keeps full-resolution exports fast.
Uint8List toneCurve(Adjustments a, int channel) {
  final lut = Uint8List(256);
  final black = a.levels.black[channel].toDouble();
  final white = math.max(black + 1, a.levels.white[channel].toDouble());
  final gain = a.whiteBalance[channel];
  final expo = math.pow(2, a.exposure * 1.5).toDouble();
  final k = 1 + a.contrast * 0.8;
  for (var i = 0; i < 256; i++) {
    var v = ((i - black) / (white - black)).clamp(0.0, 1.0);
    v = (v * gain).clamp(0.0, 1.0);
    v = (v * expo).clamp(0.0, 1.0);
    // Shadows lift / highlights recovery act on their own part of the curve.
    v += a.shadows * 0.35 * v * math.pow(1 - v, 2) * 2;
    v -= a.highlights * 0.35 * (1 - v) * v * v * 2;
    v = ((v - 0.5) * k + 0.5).clamp(0.0, 1.0);
    v = a.fade * 0.12 + v * (1 - a.fade * 0.2);
    lut[i] = (v.clamp(0.0, 1.0) * 255).round();
  }
  return lut;
}

/// Applies [a] to tightly packed RGB bytes in place.
void applyAdjustments(Uint8List rgb, int width, int height, Adjustments a) {
  if (a.isNeutral) return;
  final r = toneCurve(a, 0), g = toneCurve(a, 1), b = toneCurve(a, 2);
  final sat = 1 + a.saturation;
  final warmR = a.warmth * 18, warmB = -a.warmth * 18;
  final cx = width / 2, cy = height / 2;
  final maxD = math.sqrt(cx * cx + cy * cy);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 3;
      var rr = r[rgb[i]].toDouble();
      var gg = g[rgb[i + 1]].toDouble();
      var bb = b[rgb[i + 2]].toDouble();
      if (sat != 1) {
        final l = 0.299 * rr + 0.587 * gg + 0.114 * bb;
        rr = l + (rr - l) * sat;
        gg = l + (gg - l) * sat;
        bb = l + (bb - l) * sat;
      }
      rr += warmR;
      bb += warmB;
      if (a.vignette > 0) {
        final dx = x - cx, dy = y - cy;
        final d = math.sqrt(dx * dx + dy * dy) / maxD;
        final f = 1 - a.vignette * 0.75 * math.pow(d, 2.2);
        rr *= f;
        gg *= f;
        bb *= f;
      }
      rgb[i] = rr.round().clamp(0, 255);
      rgb[i + 1] = gg.round().clamp(0, 255);
      rgb[i + 2] = bb.round().clamp(0, 255);
    }
  }
}

/// What Smart Enhance found, so the UI can explain it.
class EnhanceReport {
  const EnhanceReport({
    required this.adjustments,
    required this.meanLuma,
    required this.meanSaturation,
    required this.colorCast,
    required this.notes,
  });
  final Adjustments adjustments;
  final double meanLuma;
  final double meanSaturation;
  final List<double> colorCast;
  final List<String> notes;
}

/// Smart Enhance: analyses the histogram and colour balance and picks corrections.
/// * per-channel 0.5% / 99.5% percentiles -> levels (fixes flat, hazy photos)
/// * gray-world white balance, limited to +-12% (removes colour casts)
/// * exposure nudge toward mid-grey, vibrance boost for dull images.
EnhanceReport analyzeForEnhance(Uint8List rgb, int width, int height) {
  final hist = List.generate(3, (_) => List<int>.filled(256, 0));
  final n = width * height;
  final step = n > 400000 ? 4 : 1; // sample large images
  var count = 0;
  var lumaSum = 0.0, satSum = 0.0;
  final sums = [0.0, 0.0, 0.0];
  for (var p = 0; p < n; p += step) {
    final i = p * 3;
    final r = rgb[i], g = rgb[i + 1], b = rgb[i + 2];
    hist[0][r]++;
    hist[1][g]++;
    hist[2][b]++;
    sums[0] += r;
    sums[1] += g;
    sums[2] += b;
    lumaSum += 0.299 * r + 0.587 * g + 0.114 * b;
    final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
    satSum += mx == 0 ? 0 : (mx - mn) / mx;
    count++;
  }
  int pct(List<int> h, double q) {
    final target = q * count;
    var acc = 0;
    for (var v = 0; v < 256; v++) {
      acc += h[v];
      if (acc >= target) return v;
    }
    return 255;
  }

  final black = [for (var c = 0; c < 3; c++) math.min(pct(hist[c], 0.005), 60)];
  final white = [for (var c = 0; c < 3; c++) math.max(pct(hist[c], 0.995), 190)];
  final means = [for (var c = 0; c < 3; c++) sums[c] / count];
  final gray = (means[0] + means[1] + means[2]) / 3;
  final gains = [for (var c = 0; c < 3; c++) (gray / math.max(1, means[c])).clamp(0.88, 1.12).toDouble()];
  final meanLuma = lumaSum / count / 255;
  final meanSat = satSum / count;

  final notes = <String>[];
  final stretch = [for (var c = 0; c < 3; c++) black[c] > 8 || white[c] < 245].any((x) => x);
  if (stretch) notes.add('Recovered contrast from a flat histogram');
  final cast = [for (var c = 0; c < 3; c++) means[c] / math.max(1, gray) - 1];
  if (gains.any((g) => (g - 1).abs() > 0.03)) {
    final strongest = cast.indexOf(cast.reduce((a, b) => a.abs() > b.abs() ? a : b));
    notes.add('Removed a ${['red', 'green', 'blue'][strongest]} colour cast');
  }
  final exposure = ((0.48 - meanLuma) * 0.9).clamp(-0.35, 0.35).toDouble();
  if (exposure.abs() > 0.05) {
    notes.add(exposure > 0 ? 'Brightened an underexposed shot' : 'Toned down an overexposed shot');
  }
  final saturation = meanSat < 0.28 ? ((0.28 - meanSat) * 1.4).clamp(0.0, 0.35).toDouble() : 0.0;
  if (saturation > 0.02) notes.add('Added vibrance to dull colours');
  if (notes.isEmpty) notes.add('Already well balanced: small polish only');

  return EnhanceReport(
    adjustments: Adjustments(
      levels: Levels(black, white),
      whiteBalance: gains,
      exposure: exposure,
      saturation: saturation,
      contrast: 0.08,
      shadows: meanLuma < 0.4 ? 0.25 : 0.1,
      highlights: meanLuma > 0.6 ? 0.25 : 0.1,
    ),
    meanLuma: meanLuma,
    meanSaturation: meanSat,
    colorCast: cast,
    notes: notes,
  );
}

/// Film-style looks. They layer on top of Smart Enhance and manual tweaks.
const presets = <String, Adjustments>{
  'Original': Adjustments(),
  'Vivid': Adjustments(contrast: 0.2, saturation: 0.35),
  'Golden': Adjustments(warmth: 0.45, saturation: 0.1, fade: 0.1, vignette: 0.25),
  'Nordic': Adjustments(warmth: -0.35, saturation: -0.15, contrast: 0.1, fade: 0.2),
  'Noir': Adjustments(saturation: -1, contrast: 0.35, vignette: 0.35),
  'Matte': Adjustments(fade: 0.55, contrast: -0.1, saturation: -0.05),
  'Drama': Adjustments(contrast: 0.45, highlights: 0.3, shadows: -0.2, vignette: 0.45),
  'Pastel': Adjustments(exposure: 0.15, saturation: -0.25, fade: 0.35, warmth: 0.1),
};

/// A tight crop around [subject] with breathing room, clamped to the image and to [aspect]
/// (width / height, null = free). Used by Smart Crop on the object ML Kit found.
({double left, double top, double width, double height}) smartCrop({
  required double imageWidth,
  required double imageHeight,
  required double left,
  required double top,
  required double width,
  required double height,
  double padding = 0.12,
  double? aspect,
}) {
  var w = width * (1 + padding * 2);
  var h = height * (1 + padding * 2);
  if (aspect != null) {
    if (w / h > aspect) {
      h = w / aspect;
    } else {
      w = h * aspect;
    }
  }
  if (w > imageWidth) {
    w = imageWidth;
    if (aspect != null) h = w / aspect;
  }
  if (h > imageHeight) {
    h = imageHeight;
    if (aspect != null) w = h * aspect;
  }
  final cx = left + width / 2, cy = top + height / 2;
  final l = (cx - w / 2).clamp(0.0, imageWidth - w).toDouble();
  final t = (cy - h / 2).clamp(0.0, imageHeight - h).toDouble();
  return (left: l, top: t, width: w, height: h);
}
