import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Tunables for the "빛줄기" (volumetric light) stage effect. Positions are
/// fractions of the card; angles are radians; everything else is 0..1 unless
/// noted. Defaults are a clear, mid-strong look; the lab fine-tunes them.
@immutable
class VolumetricLightParams {
  const VolumetricLightParams({
    this.lightX = 0.64,
    this.lightY = -0.16,
    this.direction = -0.10,
    this.spread = 0.62,
    this.color = const Color(0xFFFFC98A),
    this.intensity = 0.72,
    this.fogDensity = 0.5,
    this.shaftScale = 9,
    this.reach = 0.95,
    this.farHaze = 0.42,
    this.frontHaze = 0.26,
    this.dustAmount = 0.7,
    this.dustSpeed = 0.7,
    this.rimIntensity = 0.55,
    this.rimWidth = 3.2,
  });

  /// Fixture position as fractions of the card (y < 0 = above the top edge,
  /// i.e. "behind and above" the stage).
  final double lightX, lightY;

  /// Beam axis tilt from straight down (radians, + aims right).
  final double direction;

  /// Cone half angle (radians). Wider = broader, softer light.
  final double spread;
  final Color color;
  final double intensity;

  /// Density of the scattering medium the light is seen in.
  final double fogDensity;

  /// Number of streaks across the cone (4 = wide slabs, 16 = fine rays).
  final double shaftScale;

  /// Falloff length as a fraction of card height.
  final double reach;

  /// Aerial perspective on far background pixels (needs a depth map).
  final double farHaze;

  /// How much of the medium is drawn in front of the person (fraction of
  /// [intensity]).
  final double frontHaze;
  final double dustAmount;

  /// Dust drift speed multiplier (1 = the regular dust speed).
  final double dustSpeed;
  final double rimIntensity;

  /// Rim thickness in logical px.
  final double rimWidth;

  static const defaults = VolumetricLightParams();

  /// Fixture position in px for a layer of [size], shifted by [parallax].
  Offset lightPx(Size size, Offset parallax) =>
      Offset(size.width * lightX, size.height * lightY) + parallax;

  VolumetricLightParams copyWith({
    double? lightX,
    double? lightY,
    double? direction,
    double? spread,
    Color? color,
    double? intensity,
    double? fogDensity,
    double? shaftScale,
    double? reach,
    double? farHaze,
    double? frontHaze,
    double? dustAmount,
    double? dustSpeed,
    double? rimIntensity,
    double? rimWidth,
  }) => VolumetricLightParams(
    lightX: lightX ?? this.lightX,
    lightY: lightY ?? this.lightY,
    direction: direction ?? this.direction,
    spread: spread ?? this.spread,
    color: color ?? this.color,
    intensity: intensity ?? this.intensity,
    fogDensity: fogDensity ?? this.fogDensity,
    shaftScale: shaftScale ?? this.shaftScale,
    reach: reach ?? this.reach,
    farHaze: farHaze ?? this.farHaze,
    frontHaze: frontHaze ?? this.frontHaze,
    dustAmount: dustAmount ?? this.dustAmount,
    dustSpeed: dustSpeed ?? this.dustSpeed,
    rimIntensity: rimIntensity ?? this.rimIntensity,
    rimWidth: rimWidth ?? this.rimWidth,
  );

  @override
  bool operator ==(Object other) =>
      other is VolumetricLightParams &&
      other.lightX == lightX &&
      other.lightY == lightY &&
      other.direction == direction &&
      other.spread == spread &&
      other.color == color &&
      other.intensity == intensity &&
      other.fogDensity == fogDensity &&
      other.shaftScale == shaftScale &&
      other.reach == reach &&
      other.farHaze == farHaze &&
      other.frontHaze == frontHaze &&
      other.dustAmount == dustAmount &&
      other.dustSpeed == dustSpeed &&
      other.rimIntensity == rimIntensity &&
      other.rimWidth == rimWidth;

  @override
  int get hashCode => Object.hash(
    lightX,
    lightY,
    direction,
    spread,
    color,
    intensity,
    fogDensity,
    shaftScale,
    reach,
    farHaze,
    frontHaze,
    dustAmount,
    dustSpeed,
    rimIntensity,
    rimWidth,
  );
}

/// Live parameters every volumetric pass, the background haze and the
/// person rim light read at paint time. The preview lab writes to it; the
/// app otherwise runs on [VolumetricLightParams.defaults].
class VolumetricLightController extends ValueNotifier<VolumetricLightParams> {
  VolumetricLightController._() : super(VolumetricLightParams.defaults);
  static final instance = VolumetricLightController._();

  void reset() => value = VolumetricLightParams.defaults;
}
