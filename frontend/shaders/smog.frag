#version 460 core
#include <flutter/runtime_effect.glsl>

// Procedural stage smog. Domain-warped value-noise fBm that drifts with
// uFlow; heavier toward the floor when uBottomBias > 0. Output is additive
// light (draw with BlendMode.plus) so it never darkens the photo.
//
// Uniform float layout (setFloat index):
//  0-1 uSize | 2 uTime | 3-4 uTilt | 5-7 uColor | 8 uDensity | 9 uOctaves
//  10-11 uFlow | 12 uBottomBias
precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform vec2 uTilt;        // normalized -1..1, parallax
uniform vec3 uColor;
uniform float uDensity;    // 0..1
uniform float uOctaves;    // 2..5, quality tier
uniform vec2 uFlow;        // noise-space units per second
uniform float uBottomBias; // 0 = uniform, 1 = only near the floor

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
  for (int i = 0; i < 5; i++) {
    if (i >= octaves) break;
    value += amplitude * noise(p);
    p = rot * p * 2.03 + 7.3;
    amplitude *= 0.5;
  }
  return value;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  int octaves = int(uOctaves + 0.5);
  vec2 p = vec2(uv.x * uSize.x / uSize.y, uv.y) * 3.0 + uTilt * 0.18;
  vec2 flow = uFlow * uTime;

  // Warp the domain with a slower, larger noise so the smoke rolls.
  float warp = fbm(p * 0.6 + flow * 0.55, octaves);
  float density = fbm(p + flow + vec2(warp * 0.9, -warp * 0.6), octaves);
  density = smoothstep(0.32, 0.88, density);

  float floorWeight = mix(1.0, smoothstep(0.05, 1.0, uv.y), uBottomBias);
  float a = density * floorWeight * uDensity;
  fragColor = vec4(uColor * a, 1.0);
}
