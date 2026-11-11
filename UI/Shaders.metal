#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Brushed metal leaf for the big numerals (Gilded style, used with SwiftUI's .colorEffect).
// position: pixel inside the text, in points. size: the text's frame.
// t: seconds (wrapped). tilt: device tilt, -1...1, nudges the highlight like real metal.
// hi / mid / low: the chosen colour's bright, main and deep tones (gold, rose gold, platinum...).
[[ stitchable ]] half4 goldFoil(float2 position, half4 color, float2 size, float t, float2 tilt,
                                half4 hi, half4 mid, half4 low) {
    if (color.a < 0.002h) { return color; }
    float2 uv = position / max(size, float2(1.0f));

    // Light falls from above: pale at the top edge, the main tone in the body, a deeper
    // tone at the foot of each glyph.
    float3 cHi = float3(hi.rgb), cMid = float3(mid.rgb), cLow = float3(low.rgb);
    float3 pale = mix(cHi, float3(1.0f), 0.35f);
    float3 deep = cLow * 0.78f;
    float v = clamp(uv.y + tilt.y * 0.12f, 0.0f, 1.0f);
    float3 base = mix(pale, cHi, smoothstep(0.00f, 0.30f, v));
    base = mix(base, cMid, smoothstep(0.30f, 0.70f, v));
    base = mix(base, deep, smoothstep(0.72f, 1.05f, v));

    // Fine horizontal brushing.
    float row = floor(position.y * 1.5f);
    float grain = fract(sin(row * 12.9898f + floor(position.x * 0.08f) * 4.1414f) * 43758.5453f);
    base *= 0.95f + 0.07f * grain;

    // A soft highlight that drifts across the metal and follows the tilt.
    float d = uv.x * 0.85f + uv.y * 0.35f;
    float center = fract(t * 0.045f) * 2.6f - 0.8f + tilt.x * 0.4f;
    float band = exp(-pow((d - center) * 6.0f, 2.0f));
    base += float3(1.0f, 0.95f, 0.85f) * band * 0.38f;

    return half4(half3(clamp(base, 0.0f, 1.0f)) * color.a, color.a);
}

// A lens of living light (the Glass style's object). Drawn on a square with .colorEffect.
// energy: 0...1, how hard the PC is working (brighter core, stronger halo).
// hi / mid / low: the chosen colour's bright, main and deep tones.
[[ stitchable ]] half4 lightOrb(float2 position, half4 color, float2 size, float t, float energy,
                                half4 hi, half4 mid, half4 low) {
    float s = max(min(size.x, size.y) * 0.5f, 1.0f);
    float2 p = (position - size * 0.5f) / s;
    float r = length(p);
    float R = 0.80f;
    float3 cHi = float3(hi.rgb), cMid = float3(mid.rgb), cLow = float3(low.rgb);

    // The halo the lens throws around itself, gone before the edge of the frame.
    float halo = exp(-max(r - R, 0.0f) * 8.0f) * (0.28f + 0.42f * energy) * (1.0f - smoothstep(0.84f, 1.0f, r));
    if (r >= R) {
        float a = clamp(halo, 0.0f, 1.0f);
        return half4(half3(cMid * a), half(a));
    }

    float2 q = p / R;
    float z = sqrt(max(0.0f, 1.0f - dot(q, q)));

    // Slow currents of light inside, bent by the curve of the glass.
    float2 uv = q / (0.55f + z);
    float ang = t * 0.33f;
    float ca = cos(ang), sa = sin(ang);
    float2 w = float2(uv.x * ca - uv.y * sa, uv.x * sa + uv.y * ca);
    float n = sin(w.x * 3.1f + t * 0.7f) * cos(w.y * 2.7f - t * 0.5f);
    n += 0.5f * sin((w.x + w.y) * 5.3f + t * 1.1f + n * 2.0f);
    n += 0.25f * sin(length(w) * 9.0f - t * 1.6f);
    n = clamp(n * 0.5f + 0.5f, 0.0f, 1.0f);

    float3 inner = mix(cLow * 0.30f, cMid, smoothstep(0.22f, 0.72f, n));
    inner = mix(inner, cHi, smoothstep(0.70f, 1.0f, n) * (0.45f + 0.55f * energy));
    inner *= 0.30f + 0.70f * z;

    // Light catching the rim, and one window-like highlight.
    float fres = pow(1.0f - z, 2.4f);
    float3 col = inner + cHi * fres * 0.95f;
    float2 hp = q - float2(-0.36f, -0.42f);
    float hd = dot(hp, hp);
    col += float3(1.0f) * (exp(-hd * 20.0f) * 0.42f + exp(-hd * 150.0f) * 0.55f);
    col = clamp(col, 0.0f, 1.0f);

    float lum = max(col.r, max(col.g, col.b));
    float a = clamp(0.42f + lum * 0.9f, 0.0f, 1.0f);
    float edge = 1.0f - smoothstep(0.975f, 1.0f, r / R);
    a = mix(clamp(halo, 0.0f, 1.0f), a, edge);
    return half4(half3(col * a), half(a));
}
