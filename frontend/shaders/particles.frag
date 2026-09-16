#version 460 core
#include <flutter/runtime_effect.glsl>

// GPU particle field. The screen is divided into cells; every cell owns at
// most one particle whose position, size, rotation, fall speed, sway and
// colour are derived from a hash of the cell id — nothing is simulated on
// the CPU. Cells scroll with time so particles fall and respawn at the top.
// Up to three depth layers, spread between uDepthLo and uDepthHi, give
// parallax and scale variation; a "behind the person" layer uses the far
// range and a "in front" layer the near range.
//
// uMode 0: confetti (flat rotating slips, srcOver, premultiplied alpha).
// uMode 1: dust motes (soft glowing discs drifting up, draw additively).
//
// Optional light-cone mask (uLightMask > 0): dust is only visible where a
// fixture at uLight, aimed uLightDir radians from straight down with half
// angle uLightSpread, actually reaches — and is tinted by uTint.
//
// Uniform float layout (setFloat index):
//  0-1 uSize | 2 uTime | 3-4 uTilt(px) | 5 uLayers | 6 uCell | 7 uSpeed
//  8 uMode | 9 uScale | 10 uOpacity | 11 uSeed | 12 uDepthLo | 13 uDepthHi
//  14-15 uLight(px) | 16 uLightDir | 17 uLightSpread | 18 uLightMask
//  19 uTwinkle | 20-22 uTint
precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform vec2 uTilt;      // px shift applied to the nearest layer
uniform float uLayers;   // 1..3 (quality tier)
uniform float uCell;     // base cell size in px
uniform float uSpeed;    // base fall speed px/s (negative = rise)
uniform float uMode;
uniform float uScale;    // particle size multiplier
uniform float uOpacity;
uniform float uSeed;
uniform float uDepthLo;  // 0..1 depth of the farthest layer
uniform float uDepthHi;  // 0..1 depth of the nearest layer
uniform vec2 uLight;     // fixture position px
uniform float uLightDir; // radians from straight down
uniform float uLightSpread; // cone half angle, radians
uniform float uLightMask;   // 0 = everywhere, 1 = only inside the cone
uniform float uTwinkle;     // twinkle rate multiplier (dust)
uniform vec3 uTint;         // dust colour multiplier

out vec4 fragColor;

// Same analytic cone as god_rays.frag so dust and shafts agree.
float lightCone(vec2 frag) {
  vec2 d = frag - uLight;
  float ang = atan(d.x, max(d.y, 1.0)) - uLightDir;
  float a = abs(ang) / max(uLightSpread, 0.01);
  float env = 1.0 - smoothstep(0.35, 1.05, a);
  float fall = exp(-length(d) / (uSize.y * 1.1) * 1.2);
  return env * (0.25 + 0.75 * fall);
}

vec3 hash3(vec2 p) {
  vec3 q = vec3(
    dot(p, vec2(127.1, 311.7)),
    dot(p, vec2(269.5, 183.3)),
    dot(p, vec2(419.2, 371.9))
  );
  return fract(sin(q) * 43758.5453);
}

vec3 palette(float t) {
  // gold, pink, cyan, white, mint, pale yellow
  if (t < 0.166) return vec3(0.984, 0.749, 0.141);
  if (t < 0.333) return vec3(0.957, 0.447, 0.714);
  if (t < 0.5)   return vec3(0.133, 0.827, 0.933);
  if (t < 0.666) return vec3(1.0, 1.0, 1.0);
  if (t < 0.833) return vec3(0.525, 0.937, 0.675);
  return vec3(0.992, 0.902, 0.541);
}

// Returns premultiplied colour + alpha for one depth layer.
vec4 layer(vec2 frag, float depth, float seed) {
  float cell = uCell * (0.8 + depth * 0.9);
  float speed = uSpeed * (0.45 + depth * 0.95);
  vec2 p = frag + uTilt * (0.25 + depth * 1.75);
  p.y -= uTime * speed;
  p.x += seed * 37.0;

  vec2 id = floor(p / cell);
  vec2 f = fract(p / cell);
  vec3 h = hash3(id + seed);
  vec3 h2 = hash3(id * 1.7 + seed + 11.0);

  // Density: leave some cells empty so the field is not a lattice.
  if (h.x < 0.5) return vec4(0.0);

  float sway = sin(uTime * (0.7 + h.y * 1.1) + h.z * 6.2831) * 0.24;
  vec2 center = vec2(0.5 + sway, 0.5 + 0.22 * (h.z - 0.5));
  vec2 d = (f - center) * cell;

  float scale = uScale * (0.5 + depth * 0.8);
  float alpha;
  vec3 color;

  if (uMode < 0.5) {
    float spin = (h2.x > 0.5 ? 1.0 : -1.0) * (1.2 + h2.y * 2.6);
    float rot = uTime * spin + h2.z * 6.2831;
    float c = cos(rot), s = sin(rot);
    vec2 q = mat2(c, -s, s, c) * d;
    // Flutter: the slip turns edge-on periodically, squashing its width.
    float flutter = abs(cos(uTime * (1.6 + h2.x * 2.2) + h.z * 9.0));
    vec2 halfSize = vec2(3.4 * (0.18 + 0.82 * flutter), 7.2) * scale;
    vec2 e = abs(q) - halfSize;
    float sdf = length(max(e, 0.0)) + min(max(e.x, e.y), 0.0);
    float cov = 1.0 - smoothstep(-0.8, 0.8, sdf);
    // Soft halo on near slips reads as catching the stage light.
    float halo = depth > 0.62 ? exp(-max(sdf, 0.0) * 0.45) * 0.28 : 0.0;
    color = palette(h2.y);
    // Fake lighting: brighter when facing the viewer.
    color *= 0.75 + 0.45 * flutter;
    alpha = (cov + halo) * (0.55 + 0.45 * depth);
  } else {
    float r = (1.2 + h2.x * 1.8) * scale;
    float len = length(d);
    float core = 1.0 - smoothstep(0.0, r, len);
    float glow = exp(-len / (r * 2.2)) * 0.5;
    float twinkle = 0.55 + 0.45 * sin(uTime * uTwinkle * (1.5 + h2.y * 2.5) + h2.z * 6.2831);
    color = mix(vec3(0.87, 0.91, 1.0), vec3(1.0, 0.95, 0.8), h2.z) * uTint;
    alpha = (core + glow) * twinkle * (0.35 + 0.65 * depth);
  }
  alpha = clamp(alpha * uOpacity, 0.0, 1.0);
  return vec4(color * alpha, alpha);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  int layers = int(uLayers + 0.5);
  float mask = mix(1.0, lightCone(frag), uLightMask);
  vec4 result = vec4(0.0);
  // Far to near so nearer particles occlude farther ones.
  for (int i = 0; i < 3; i++) {
    if (i >= layers) break;
    float t = layers == 1 ? 0.75 : float(i) / float(layers - 1);
    float depth = mix(uDepthLo, uDepthHi, t);
    vec4 l = layer(frag, depth, uSeed + float(i) * 19.0);
    result = result * (1.0 - l.a) + l;
  }
  fragColor = result * mask;
}
