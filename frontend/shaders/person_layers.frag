#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform vec2 uTilt;
uniform float uStrength;
uniform float uLayerGain;
uniform float uReliefGain;
uniform float uLayerCount;
// Normalised median depth per layer, far to near. Unused slots are ignored.
uniform vec4 uLayerDepths;
uniform sampler2D uImage;
uniform sampler2D uDepth;
// R, G, B hold the weights of the far layers; the nearest layer is the
// remainder, so four layers fit without touching the (premultiplied) alpha.
uniform sampler2D uParts;
out vec4 fragColor;

float layerWeight(int k, int count, vec4 parts) {
  if (k == count - 1) return clamp(1.0 - parts.r - parts.g - parts.b, 0.0, 1.0);
  if (k == 0) return parts.r;
  if (k == 1) return parts.g;
  return parts.b;
}

// Each layer slides as a whole by its own depth, plus a small relief inside.
// A layer only paints where the displaced sample still belongs to it, so a
// hand in front of the chest moves without stretching the chest behind it.
void composite(int k, float layerDepth, int count, vec2 uv, vec2 shift,
               vec4 base, inout vec3 color) {
  if (k >= count) return;
  vec2 src = clamp(uv - shift * (layerDepth - 0.5) * uLayerGain, 0.0, 1.0);
  float d = texture(uDepth, src).r;
  src = clamp(src - shift * (d - layerDepth) * uReliefGain, 0.0, 1.0);
  vec4 sampled = texture(uImage, src);
  float w = layerWeight(k, count, texture(uParts, src));
  w *= smoothstep(0.5, 0.9, sampled.a);
  if (w < 0.02) return;
  vec3 rgb = sampled.rgb * (base.a / max(sampled.a, 0.0001));
  color = mix(color, rgb, w);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 base = texture(uImage, uv);
  // Fixed alpha keeps the person's silhouette and bounding box anchored.
  float mask = base.a;
  mask = min(mask, texture(uImage, clamp(uv + vec2(0.02, 0), 0.0, 1.0)).a);
  mask = min(mask, texture(uImage, clamp(uv - vec2(0.02, 0), 0.0, 1.0)).a);
  mask = min(mask, texture(uImage, clamp(uv + vec2(0, 0.02), 0.0, 1.0)).a);
  mask = min(mask, texture(uImage, clamp(uv - vec2(0, 0.02), 0.0, 1.0)).a);
  float edge = smoothstep(0.0, 0.08, min(min(uv.x, 1.0-uv.x), min(uv.y, 1.0-uv.y)));
  float interior = smoothstep(0.85, 1.0, mask) * edge;
  vec2 shift = uTilt * uStrength * interior;
  int count = int(uLayerCount + 0.5);
  // Gaps opened between layers keep the undisplaced pixel underneath.
  vec3 color = base.rgb;
  composite(0, uLayerDepths.x, count, uv, shift, base, color);
  composite(1, uLayerDepths.y, count, uv, shift, base, color);
  composite(2, uLayerDepths.z, count, uv, shift, base, color);
  composite(3, uLayerDepths.w, count, uv, shift, base, color);
  fragColor = vec4(color, base.a);
}
