#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2  uSize;

out vec4 fragColor;

// Hash sin distorsión
float hash(vec2 p) {
  p = fract(p * vec2(127.1, 311.7));
  p += dot(p, p + 19.19);
  return fract(p.x * p.y);
}

// Noise suave 2D
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);

  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));

  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian Motion — capas de ruido
float fbm(vec2 p) {
  float v = 0.0;
  float amp = 0.5;
  float freq = 1.0;
  for (int i = 0; i < 6; i++) {
    v   += amp * noise(p * freq);
    amp  *= 0.5;
    freq *= 2.1;
  }
  return v;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  // Relación de aspecto
  float aspect = uSize.x / uSize.y;
  vec2 p = vec2(uv.x * aspect, uv.y);

  float t = uTime * 0.025;

  // Dos capas de fbm desplazadas en el tiempo para el fluido
  vec2 q = vec2(
    fbm(p + vec2(0.0, t)),
    fbm(p + vec2(5.2, t + 1.3))
  );

  vec2 r = vec2(
    fbm(p + 4.0 * q + vec2(1.7, t * 0.8)),
    fbm(p + 4.0 * q + vec2(9.2, t * 0.6 + 2.8))
  );

  float f = fbm(p + 4.5 * r + vec2(t * 0.3, 0.0));

  // Rango [0,1] → suavizado
  f = smoothstep(0.2, 0.85, f);

  // Paleta: negro puro ↔ crema #F3EBD6
  vec3 cream = vec3(0.953, 0.922, 0.839);
  vec3 black = vec3(0.04,  0.04,  0.04);

  // Añadir contraste con pow para realzar las venas
  float mask = pow(f, 1.4);

  vec3 col = mix(black, cream, mask);

  fragColor = vec4(col, 1.0);
}
