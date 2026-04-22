#include <metal_stdlib>
using namespace metal;

[[ stitchable ]]
float2 liquidWarp(float2 position, float time) {
    float wave1 = sin(position.y * 0.015 + time * 0.6) * 12.0;
    float wave2 = cos(position.x * 0.02  - time * 0.4) * 10.0;
    float distortion = wave1 + wave2;
    position.x += distortion * 0.4;
    position.y += distortion * 0.2;
    return position;
}
