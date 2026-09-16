#version 460 core
#include <flutter/runtime_effect.glsl>

// Volumetric light cones. Each cone is an analytic wedge from a fixture at
// the top edge to an aim point on the floor; its intensity is modulated by
// drifting fBm "smoke" so the beam looks like light scattering in haze,
// not a flat gradient. Includes lens glare at the fixture and a floor pool.
// Additive output: draw with BlendMode.plus.
//
// Cone vec4 = (originX px, aimX px, halfWidth px at floor, intensity 0..1).
// Uniform float layout (setFloat index):
//  0-1 uSize | 2 uTime | 3-4 uTilt(px) | 5-8 uCone0 | 9-12 uCone1
//  13-16 uCone2 | 17-19 uColor0 | 20-22 uColor1 | 23-25 uColor2
//  26 uOctaves | 27 uHaze
precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform vec2 uTilt;
uniform vec4 uCone0;
uniform vec4 uCone1;
uniform vec4 uCone2;
uniform vec3 uColor0;
uniform vec3 uColor1;
uniform vec3 uColor2;
uniform float uOctaves;
uniform float uHaze;     // 0..1 how much the smoke texture shows

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
    p = rot * p * 2.1 + 3.7;
    amplitude *= 0.5;
  }
  return value;
}

vec3 cone(vec4 c, vec3 color, vec2 frag, float smoke) {
  if (c.w <= 0.0) return vec3(0.0);
  float y = clamp(frag.y / uSize.y, 0.0, 1.0);
  float cx = mix(c.x, c.y, y);
  float hw = mix(uSize.x * 0.012, c.z, y);
  float lateral = abs(frag.x - cx) / hw;
  float shape = 1.0 - smoothstep(0.55, 1.0, lateral);
  float core = pow(max(1.0 - lateral, 0.0), 2.5);
  float distanceFade = 1.0 - y * 0.7;
  float beam = (shape * 0.55 + core * 0.75) * distanceFade * smoke;

  vec2 pool = (frag - vec2(c.y, uSize.y)) / vec2(c.z * 1.15, c.z * 0.32);
  float floorPool = exp(-dot(pool, pool)) * 0.6;

  float glare = exp(-length(frag - vec2(c.x, 0.0)) / (uSize.x * 0.045));
  vec3 glareColor = mix(color, vec3(1.0), 0.55) * glare * 1.1;

  return (color * (beam * 0.62 + floorPool) + glareColor) * c.w;
}

void main() {
  vec2 frag = FlutterFragCoord().xy + uTilt;
  int octaves = int(uOctaves + 0.5);
  vec2 p = frag / uSize.y * 2.4;
  float n = fbm(p + vec2(uTime * 0.06, -uTime * 0.11), octaves);
  float smoke = mix(1.0, 0.45 + 0.9 * n, uHaze);

  vec3 color = cone(uCone0, uColor0, frag, smoke)
             + cone(uCone1, uColor1, frag, smoke)
             + cone(uCone2, uColor2, frag, smoke);
  fragColor = vec4(color, 1.0);
}
