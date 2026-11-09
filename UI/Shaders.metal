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
