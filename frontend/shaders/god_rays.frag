#version 460 core
#include <flutter/runtime_effect.glsl>

// Volumetric light shafts ("god rays") from one warm fixture placed above
// and behind the stage. Everything here is a screen-space approximation:
// the cone is analytic (angle from the fixture), the individual shafts are
// 1D noise along that angle, and the scattering medium is a slowly
// domain-warped fBm so brightness breathes without a repeating pattern.
// There is no real depth: "far" is simply "closer to the fixture" and the
// behind/front split is done by drawing the pass below or above the person
// layer with a different uSection.
// Additive output: draw with BlendMode.plus.
//
// Uniform float layout (setFloat index):
//  0-1 uSize | 2 uTime | 3-4 uTilt(px) | 5-6 uLight(px) | 7 uDir(rad)
//  8 uSpread(rad) | 9-11 uColor | 12 uIntensity | 13 uFog | 14 uShaftScale
//  15 uOctaves | 16 uReach | 17 uSection
precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform vec2 uTilt;        // parallax shift in px
uniform vec2 uLight;       // fixture position in px (usually above the card)
uniform float uDir;        // beam axis, radians from straight down (+ = right)
uniform float uSpread;     // cone half angle in radians
uniform vec3 uColor;
uniform float uIntensity;  // 0..1
uniform float uFog;        // 0..1 scattering medium density
uniform float uShaftScale; // streak count across the cone (4..16)
uniform float uOctaves;    // fBm octaves (2..4), quality tier
uniform float uReach;      // falloff length as a fraction of the card height
uniform float uSection;    // 0 = behind the person, 1 = in front of the person

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
  float value = 0.0;
  float amplitude = 0.5;
  const mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
  for (int i = 0; i < 4; i++) {
    if (i >= octaves) break;
    value += amplitude * noise(p);
    p = rot * p * 2.07 + 5.1;
    amplitude *= 0.5;
  }
  return value;
}

void main() {
  vec2 frag = FlutterFragCoord().xy + uTilt;
  int octaves = int(uOctaves + 0.5);
  float t = uTime;

  vec2 d = frag - uLight;
  float dist = length(d);
  // Angle measured from straight down so the fixture aims down the card.
  float ang = atan(d.x, max(d.y, 1.0)) - uDir;
  float a = ang / max(uSpread, 0.01);            // -1..1 inside the cone
  float env = 1.0 - smoothstep(0.42, 1.0, abs(a));
  env *= smoothstep(-40.0, 60.0, d.y);           // nothing above the fixture

  // Shafts: streaks live in angle space and drift very slowly, with a
  // second, finer field at an unrelated rate so the pattern never loops.
  float shaftCoord = a * uShaftScale;
  float s1 = fbm(vec2(shaftCoord + t * 0.021, dist / uSize.y * 0.35 - t * 0.017), octaves);
  float s2 = noise(vec2(shaftCoord * 2.7 - t * 0.013, 5.0 + t * 0.011));
  float shafts = smoothstep(0.30, 0.90, s1 * 0.75 + s2 * 0.40);

  // Strong at the fixture, fading as the beam spreads and scatters away.
  float r = dist / (uSize.y * max(uReach, 0.05));
  float fall = exp(-r * 1.7);

  // The medium: drifting, domain-warped haze the light scatters in.
  vec2 p = frag / uSize.y * 2.0;
  float warp = fbm(p * 0.55 + vec2(t * 0.010, -t * 0.016), octaves);
  float medium = fbm(p + vec2(t * 0.018, t * 0.030) + warp * 0.55, octaves);
  float scatter = mix(0.55, 1.25, medium);

  float total;
  if (uSection < 0.5) {
    float beam = env * (0.30 + 0.70 * shafts) * fall * scatter;
    // Light bouncing inside the cone: soft fill that grows with fog density.
    float fill = env * fall * scatter * uFog * 0.45;
    // Faint ambient fog everywhere, denser toward the top (the far stage).
    float height = clamp(1.0 - frag.y / uSize.y, 0.0, 1.0);
    float ambient = uFog * 0.10 * height * mix(0.7, 1.3, medium);
    // Fixture glare, mostly off the top edge.
    float glare = exp(-dist / (uSize.x * 0.07)) * 0.5;
    total = beam + fill + ambient + glare;
  } else {
    // In front of the person only the medium is visible: no sharp shafts,
    // no glare, so the face and clothes keep their detail.
    float height = clamp(1.0 - frag.y / uSize.y, 0.0, 1.0);
    float ambient = uFog * 0.08 * height * mix(0.7, 1.3, medium);
    total = env * fall * scatter * 0.35 + ambient;
  }
  vec3 color = uColor * total * uIntensity * 0.55;
  fragColor = vec4(color, 1.0);
}
