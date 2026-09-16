#version 460 core
#include <flutter/runtime_effect.glsl>

// One-sided rim light derived from the person cut-out's alpha mask. A
// pixel is lit when it is inside the silhouette but its neighbour toward
// the light is outside — that is the contour facing the fixture. The tint
// is mixed with the underlying colour so hair stays hair and skin stays
// skin; nothing is applied inside the silhouette.
// Additive output: draw with BlendMode.plus over the person.
//
// Uniform float layout (setFloat index):
//  0-1 uOrigin(px) | 2-3 uSize(px) | 4-5 uLight(uv) | 6 uWidth(px)
//  7-9 uColor | 10 uIntensity | 11 uTopBias
precision highp float;

uniform vec2 uOrigin;     // top-left of the drawn image, px
uniform vec2 uSize;       // drawn image size, px
uniform vec2 uLight;      // fixture position in image uv (y down, may be < 0)
uniform float uWidth;     // rim thickness in px
uniform vec3 uColor;
uniform float uIntensity; // 0..1
uniform float uTopBias;   // 0..1 how much more the top of the person catches
uniform sampler2D uImage;

out vec4 fragColor;

void main() {
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  vec4 c = texture(uImage, uv);
  float a = c.a;
  vec2 toLight = normalize(uLight - uv);
  vec2 stepUv = toLight * uWidth / uSize;
  float a0 = texture(uImage, clamp(uv + stepUv * 0.5, 0.0, 1.0)).a;
  float a1 = texture(uImage, clamp(uv + stepUv, 0.0, 1.0)).a;
  float a2 = texture(uImage, clamp(uv + stepUv * 2.2, 0.0, 1.0)).a;
  float edge = clamp((1.0 - a0) * 0.5 + (1.0 - a1) * 0.6 + (1.0 - a2) * 0.3, 0.0, 1.0);
  float rim = pow(a * edge, 1.4);
  // The fixture is above: shoulders and hair catch more than the feet.
  float heightGain = mix(1.0, 1.0 - uv.y, uTopBias);
  vec3 base = c.rgb / max(a, 0.0001);
  vec3 light = mix(uColor, base, 0.3);
  fragColor = vec4(light * rim * heightGain * uIntensity, 1.0);
}
