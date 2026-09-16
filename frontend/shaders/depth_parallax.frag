#version 460 core
#include <flutter/runtime_effect.glsl>

// Per-pixel depth parallax: displaces the photo by its depth map so near
// pixels move further than far pixels when the card tilts (2.5D photo).
// The image is drawn "contain" inside uSize with an overscan zoom so that
// displacement never reveals empty edges.
//
// Aerial perspective (uHaze > 0): far pixels (low depth) lose contrast and
// take on the haze colour, so a volumetric light effect reads as filling a
// room rather than being pasted on top. uHaze = 0 leaves the photo intact.
//
// Uniform float layout (setFloat index):
//  0-1 uSize | 2-3 uShift | 4 uZoom | 5-6 uImageSize | 7 uHaze | 8-10 uHazeColor
precision highp float;

uniform vec2 uSize;        // widget size in px
uniform vec2 uShift;       // parallax shift in uv units for depth = 1 (near)
uniform float uZoom;       // overscan zoom, >= 1
uniform vec2 uImageSize;   // photo size in px
uniform float uHaze;       // 0..1 aerial haze strength
uniform vec3 uHazeColor;
uniform sampler2D uImage;
uniform sampler2D uDepth;

out vec4 fragColor;

const vec3 kBackdrop = vec3(0.045, 0.06, 0.10);

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float scale = min(uSize.x / uImageSize.x, uSize.y / uImageSize.y);
  vec2 drawn = uImageSize * scale;
  vec2 origin = (uSize - drawn) * 0.5;
  vec2 uv = (frag - origin) / drawn;
  uv = (uv - 0.5) / uZoom + 0.5;

  // Two-tap refinement: sample depth where the pixel came from.
  float d0 = texture(uDepth, clamp(uv, 0.0, 1.0)).r;
  vec2 probe = uv - uShift * (0.25 + 0.75 * d0);
  float d1 = texture(uDepth, clamp(probe, 0.0, 1.0)).r;
  float d = mix(d0, d1, 0.6);
  vec2 duv = uv - uShift * (0.25 + 0.75 * d);

  vec2 cuv = clamp(duv, 0.0, 1.0);
  vec4 col = texture(uImage, cuv);
  vec2 edge = abs(duv - 0.5) - 0.5;
  float outside = max(edge.x, edge.y);
  float inside = 1.0 - smoothstep(0.0, 0.012, outside);

  // Outside the photo: darkened edge extension keeps letterboxes cinematic.
  vec3 extended = mix(kBackdrop, col.rgb * 0.30, col.a);
  vec3 rgb = mix(extended, col.rgb, inside * col.a);

  // Depth is "nearness" (1 = near). Far pixels sit in more air.
  float far = 1.0 - d;
  float air = uHaze * smoothstep(0.15, 0.95, far);
  float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
  vec3 flattened = mix(rgb, vec3(luma), air * 0.35);     // lower contrast
  rgb = mix(flattened, uHazeColor, air * 0.28);                // tinted haze
  fragColor = vec4(rgb, 1.0);
}
