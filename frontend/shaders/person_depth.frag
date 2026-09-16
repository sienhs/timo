#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform vec2 uTilt;
uniform float uStrength;
uniform sampler2D uImage;
uniform sampler2D uDepth;
out vec4 fragColor;

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
  float depth = texture(uDepth, uv).r - 0.5;
  vec2 displaced = clamp(uv - uTilt * uStrength * depth * interior, 0.0, 1.0);
  vec4 warped = texture(uImage, displaced);
  // Sampled colors are premultiplied; preserve the original alpha even at hair edges.
  vec3 color = warped.rgb * (base.a / max(warped.a, 0.0001));
  float blend = interior * smoothstep(0.85, 1.0, warped.a);
  fragColor = vec4(mix(base.rgb, color, blend), base.a);
}
