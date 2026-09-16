#version 460 core
#include <flutter/runtime_effect.glsl>

// Ambient "aurora" backdrop: three drifting soft light blobs on a deep navy
// ground with film grain and a vignette. Blob colours are uniforms so the
// backdrop can take the palette of the photo it sits behind, and the
// ambient channels (energy, focus, glow) let UI motion steer it.
//
// Uniform float layout (setFloat index):
//  0-1 uSize | 2 uTime | 3 uIntensity | 4-6 uColorA | 7-9 uColorB
//  10-12 uColorC | 13 uEnergy | 14-15 uFocus | 16 uFocusStrength | 17 uGlow
//  18 uBurst
precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform vec3 uColorA;
uniform vec3 uColorB;
uniform vec3 uColorC;
uniform float uEnergy;         // 0..1 drift speed / brightness
uniform vec2 uFocus;           // 0..1 screen position the third blob drifts to
uniform float uFocusStrength;  // 0..1 how far it has moved from its orbit
uniform float uGlow;           // 0..1 warm-up near the bottom (CTA press)
uniform float uBurst;          // 0..1 momentary flash

out vec4 fragColor;

vec3 blob(vec2 p, vec2 center, vec3 color, float radius) {
  float d = length(p - center);
  return color * smoothstep(radius, 0.0, d);
}

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * (0.55 + 0.9 * uEnergy);
  float bright = uIntensity * (0.8 + 0.5 * uEnergy + 0.6 * uBurst);

  vec3 color = vec3(0.027, 0.039, 0.070);
  color += blob(p, vec2(0.18 * aspect + 0.16 * sin(t * 0.50), 0.22 + 0.10 * cos(t * 0.41)),
                uColorA * 0.62, 0.62) * bright;
  color += blob(p, vec2(0.86 * aspect + 0.12 * cos(t * 0.37), 0.12 + 0.14 * sin(t * 0.63)),
                uColorB * 0.55, 0.55) * bright;

  vec2 orbit = vec2(0.62 * aspect + 0.22 * sin(t * 0.29 + 1.0), 0.80 + 0.10 * sin(t * 0.47));
  vec2 target = vec2(uFocus.x * aspect, uFocus.y);
  vec2 centerC = mix(orbit, target, uFocusStrength);
  float radiusC = mix(0.68, 0.42, uFocusStrength);
  color += blob(p, centerC, uColorC * (0.40 + 0.35 * uFocusStrength), radiusC) * bright;

  // Warm pool behind the primary button when it is pressed.
  color += blob(p, vec2(0.5 * aspect, 1.05), uColorA * 0.9, 0.7) * uGlow * uIntensity;

  color += hash(uv * uSize + fract(uTime) * 17.0) * 0.028;
  color *= 1.0 - 0.38 * length(uv - 0.5);
  fragColor = vec4(color, 1.0);
}
