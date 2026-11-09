#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Brushed gold leaf for the big numerals (used with SwiftUI's .colorEffect).
// position: pixel inside the text, in points. size: the text's frame.
// t: seconds (wrapped). tilt: device tilt, -1...1, nudges the highlight like real metal.
[[ stitchable ]] half4 goldFoil(float2 position, half4 color, float2 size, float t, float2 tilt) {
    if (color.a < 0.002h) { return color; }
    float2 uv = position / max(size, float2(1.0));

    // Light falls from above: pale champagne at the top edge, weathered gold in the
    // body, a deeper bronze at the foot of each glyph.
    float3 pale   = float3(0.957, 0.918, 0.769);   // #F4EAC4
    float3 aged   = float3(0.925, 0.894, 0.706);   // #ECE4B4
    float3 gold   = float3(0.784, 0.678, 0.525);   // #C8AD86
    float3 bronze = float3(0.560, 0.430, 0.270);
    float v = clamp(uv.y + tilt.y * 0.12, 0.0, 1.0);
    float3 base = mix(pale, aged, smoothstep(0.00, 0.30, v));
    base = mix(base, gold, smoothstep(0.30, 0.70, v));
    base = mix(base, bronze, smoothstep(0.72, 1.05, v));

    // Fine horizontal brushing.
    float row = floor(position.y * 1.5);
    float grain = fract(sin(row * 12.9898 + floor(position.x * 0.08) * 4.1414) * 43758.5453);
    base *= 0.95 + 0.07 * grain;

    // A soft highlight that drifts across the metal and follows the tilt.
    float d = uv.x * 0.85 + uv.y * 0.35;
    float center = fract(t * 0.045) * 2.6 - 0.8 + tilt.x * 0.4;
    float band = exp(-pow((d - center) * 6.0, 2.0));
    base += float3(1.0, 0.94, 0.80) * band * 0.38;

    return half4(half3(clamp(base, 0.0f, 1.0f)) * color.a, color.a);
}
