#version 460 core
#include <flutter/runtime_effect.glsl>

// Holographic foil sheen. Additive light layer: an iridescent band sweeps
// across the card following tilt, fine micro-lines catch the light and the
// rim glows. Draw with BlendMode.plus.
precision highp float;

uniform vec2 uSize;
uniform vec2 uTilt;        // normalized -1..1
uniform float uTime;
uniform float uIntensity;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float diag = uv.x * 0.70 + uv.y * 0.70;
  float band = uv.x * 0.8 + uv.y * 0.6 + uTilt.x * 0.9 - uTilt.y * 0.5 + uTime * 0.04;
  vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (band * 1.6 + vec3(0.0, 0.33, 0.67)));

  float pos = 0.72 + uTilt.x * 0.55 - uTilt.y * 0.35;
  float sheen = exp(-pow((diag - pos) * 3.2, 2.0));
  float spec = pow(sheen, 3.0);

  float lines = 0.5 + 0.5 * sin((uv.x * 0.55 - uv.y) * uSize.y * 0.55 + uTilt.x * 22.0);
  vec3 color = rainbow * sheen * (0.78 + 0.22 * lines) * 0.55;
  color += vec3(1.0) * spec * 0.30;

  vec2 e = min(uv, 1.0 - uv);
  float rim = 1.0 - smoothstep(0.0, 0.055, min(e.x, e.y));
  float rimSide = 0.5 + 0.5 * (uTilt.x * (uv.x - 0.5) * 2.0 + uTilt.y * (uv.y - 0.5) * 2.0);
  color += rainbow * rim * rimSide * 0.45;

  fragColor = vec4(color * uIntensity, 1.0);
}
