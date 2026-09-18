#include <metal_stdlib>
using namespace metal;

constant float MAX_TILT = 0.84106867;
constant float3 DARK = float3(0.003, 0.004, 0.005);
constant float GOLDEN_ANGLE = 2.39996323;

struct Uniforms {
    float2 imageSize;
    float2 cover;
    float aspect;
    float turn;
    float blurStrength;
    float refractionStrength;
    float chromaticStrength;
    float edgeGlow;
    float reflectionIntensity;
    float saturation;
    float contrast;
    float darknessStrength;
    float blurCurve;
    float perspectiveStrength;
    float eyeHeightCM;
    float eyeDistanceCM;
    int effectMode;
    int performanceMode;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut foldVertex(uint vid [[vertex_id]]) {
    const float2 positions[6] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0)
    };

    VertexOut out;
    float2 pos = positions[vid];
    out.position = float4(pos, 0.0, 1.0);
    out.uv = float2(pos.x * 0.5 + 0.5, 0.5 - pos.y * 0.5);
    return out;
}

inline float hash21(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

inline float3 tone(float3 c, constant Uniforms &u) {
    float luma = dot(c, float3(0.2126, 0.7152, 0.0722));
    c = mix(float3(luma), c, u.saturation);
    c = (c - 0.5) * u.contrast + 0.5;
    return clamp(c, 0.0, 1.4);
}

inline float3 vogelBlur(
    texture2d<float> tex,
    sampler s,
    float2 uv,
    float radius,
    float2 uiPixel,
    float2 pixel,
    int performanceMode
) {
    int sampleCount = performanceMode == 0 ? 14 : (performanceMode == 2 ? 42 : 26);
    float rotation = (hash21(pixel) - 0.5) * 0.55;
    float cr = cos(rotation);
    float sr = sin(rotation);
    float baseLod = clamp(log2(1.0 + radius * 0.16), 0.0, 2.0);

    float3 accum = float3(0.0);
    float weightSum = 0.0;

    for (int i = 0; i < 42; ++i) {
        if (i >= sampleCount) { break; }
        float fi = float(i);
        float r = sqrt((fi + 0.5) / float(sampleCount));
        float theta = fi * GOLDEN_ANGLE;
        float2 dir = float2(cos(theta), sin(theta));
        dir = float2(dir.x * cr - dir.y * sr, dir.x * sr + dir.y * cr);

        float2 suv = clamp(uv + dir * (r * radius * uiPixel), 0.0, 1.0);
        float w = exp(-2.25 * r * r);
        float lod = mix(0.0, baseLod, smoothstep(0.15, 0.92, r));

        accum += tex.sample(s, suv, level(lod)).rgb * w;
        weightSum += w;
    }

    return accum / max(0.0001, weightSum);
}

inline float3 naturalGlass(
    texture2d<float> tex,
    sampler s,
    float2 uv,
    float radius,
    float2 uiPixel,
    float2 pixel,
    constant Uniforms &u
) {
    float2 n = float2(
        sin((uv.y * 12.0 + uv.x * 2.0) + u.turn * 2.5),
        cos((uv.x * 10.0 - uv.y * 1.5) + u.turn * 2.0)
    );
    float2 refracted = clamp(uv + n * uiPixel * (4.0 * u.refractionStrength * u.turn), 0.0, 1.0);
    return vogelBlur(tex, s, refracted, radius, uiPixel, pixel, u.performanceMode);
}

inline float3 duoGlass(
    texture2d<float> tex,
    sampler s,
    float2 uv,
    float radius,
    float2 uiPixel,
    float2 pixel,
    constant Uniforms &u
) {
    float wave = sin(uv.y * 18.0 + u.turn * 4.0) * 0.5 + cos(uv.x * 8.0 - u.turn * 2.5) * 0.5;
    float2 shift = float2(wave, -wave * 0.35) * uiPixel * (9.0 * u.refractionStrength * u.turn);
    float3 a = vogelBlur(tex, s, clamp(uv + shift, 0.0, 1.0), radius * 0.9, uiPixel, pixel, u.performanceMode);
    float3 b = vogelBlur(tex, s, clamp(uv - shift * 0.55, 0.0, 1.0), radius * 0.55, uiPixel, pixel + 17.0, u.performanceMode);
    return mix(a, b, 0.26);
}

inline float3 frostedGlass(
    texture2d<float> tex,
    sampler s,
    float2 uv,
    float radius,
    float2 uiPixel,
    float2 pixel,
    constant Uniforms &u
) {
    float3 c = vogelBlur(tex, s, uv, radius * 1.35 + 2.0, uiPixel, pixel, u.performanceMode);
    float grain = (hash21(pixel * 0.67) - 0.5) * 0.018 * smoothstep(0.1, 1.0, u.turn);
    return c + grain;
}

inline float3 prismGlass(
    texture2d<float> tex,
    sampler s,
    float2 uv,
    float radius,
    float2 uiPixel,
    float2 pixel,
    constant Uniforms &u
) {
    float2 axis = normalize(float2(0.85, -0.52));
    float amount = (2.0 + 13.0 * u.chromaticStrength) * u.turn;
    float2 delta = axis * uiPixel * amount;

    float3 base = vogelBlur(tex, s, uv, radius * 0.60, uiPixel, pixel, u.performanceMode);
    float r = tex.sample(s, clamp(uv + delta, 0.0, 1.0), level(0.5)).r;
    float g = base.g;
    float b = tex.sample(s, clamp(uv - delta, 0.0, 1.0), level(0.5)).b;
    return mix(base, float3(r, g, b), clamp(0.18 + u.chromaticStrength * 0.64, 0.0, 0.88));
}

inline float3 deepGlass(
    texture2d<float> tex,
    sampler s,
    float2 uv,
    float radius,
    float2 uiPixel,
    float2 pixel,
    constant Uniforms &u
) {
    float3 c = vogelBlur(tex, s, uv, radius * 1.08, uiPixel, pixel, u.performanceMode);
    c *= float3(0.88, 0.94, 1.02);
    c *= 1.0 - 0.22 * u.turn;
    return c;
}

inline float3 crystalGlass(
    texture2d<float> tex,
    sampler s,
    float2 uv,
    float radius,
    float2 uiPixel,
    float2 pixel,
    constant Uniforms &u
) {
    float2 n = float2(sin(uv.y * 22.0), cos(uv.x * 19.0));
    float2 shift = n * uiPixel * (5.0 * u.refractionStrength * u.turn);
    float3 sharp = tex.sample(s, clamp(uv + shift, 0.0, 1.0), level(0.0)).rgb;
    float3 soft = vogelBlur(tex, s, uv, radius * 0.34, uiPixel, pixel, u.performanceMode);
    return mix(sharp, soft, 0.28 + 0.20 * u.blurStrength);
}

inline float3 softFocusGlass(
    texture2d<float> tex,
    sampler s,
    float2 uv,
    float radius,
    float2 uiPixel,
    float2 pixel,
    constant Uniforms &u
) {
    float3 base = vogelBlur(tex, s, uv, radius * 0.90, uiPixel, pixel, u.performanceMode);
    float3 bloom = vogelBlur(tex, s, uv, radius * 1.8 + 4.0, uiPixel, pixel + 31.0, u.performanceMode);
    return base + max(bloom - 0.55, 0.0) * 0.22;
}

inline float3 voidGlass(
    texture2d<float> tex,
    sampler s,
    float2 uv,
    float radius,
    float2 uiPixel,
    float2 pixel,
    constant Uniforms &u
) {
    float3 c = vogelBlur(tex, s, uv, radius * 0.85, uiPixel, pixel, u.performanceMode);
    float vignette = smoothstep(0.9, 0.12, distance(uv, float2(0.5)));
    return c * mix(0.58, 1.0, vignette);
}

fragment float4 foldFragment(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler s [[sampler(0)]],
    constant Uniforms &u [[buffer(0)]]
) {
    float turn = clamp(u.turn, 0.0, 1.0);
    float2 uiPixel = 2.0 / max(float2(1.0), u.imageSize);
    float2 baseUV = (in.uv - 0.5) * u.cover + 0.5;

    if (turn <= 0.00001) {
        return float4(tone(tex.sample(s, baseUV, level(0.0)).rgb, u), 1.0);
    }

    float fromHinge = clamp(1.0 - in.uv.y, 0.0, 1.0);
    float bend = turn * MAX_TILT;
    float cosine = cos(bend);
    float sine = sin(bend);

    float invAspect = 1.0 / max(0.1, u.aspect);
    float viewingDistance = clamp(u.eyeDistanceCM / 60.0, 0.45, 2.2);
    float viewingHeight = clamp(u.eyeHeightCM / 45.0, 0.45, 2.2);

    float eye = 3.2 * viewingDistance * max(invAspect, 1.0);
    float depthScale = mix(0.72, 0.92, clamp(viewingHeight * 0.5, 0.0, 1.0));
    float depth = fromHinge * (depthScale * invAspect) * sine * max(0.0, u.perspectiveStrength);
    float perspective = eye / max(0.02, eye - depth);

    float2 plane;
    plane.y = 1.0 - fromHinge * cosine * perspective;
    plane.x = 0.5 + (in.uv.x - 0.5) * perspective;

    float verticalParallax = (viewingHeight - 1.0) * sine * fromHinge * 0.018;
    plane.y += verticalParallax;

    float blurSpread = pow(smoothstep(0.0, 0.88, fromHinge), max(0.25, u.blurCurve));
    float motion = pow(turn, max(0.25, u.blurCurve)) * mix(0.20, 1.0, blurSpread);
    float radius = 54.0 * motion * max(0.02, u.blurStrength);

    float2 sampleUV = (plane - 0.5) * u.cover + 0.5;
    sampleUV = clamp(sampleUV, 0.0, 1.0);

    float3 color;
    if (u.effectMode == 1) {
        color = duoGlass(tex, s, sampleUV, radius, uiPixel, in.position.xy, u);
    } else if (u.effectMode == 2) {
        color = frostedGlass(tex, s, sampleUV, radius, uiPixel, in.position.xy, u);
    } else if (u.effectMode == 3) {
        color = prismGlass(tex, s, sampleUV, radius, uiPixel, in.position.xy, u);
    } else if (u.effectMode == 4) {
        color = deepGlass(tex, s, sampleUV, radius, uiPixel, in.position.xy, u);
    } else if (u.effectMode == 5) {
        color = crystalGlass(tex, s, sampleUV, radius, uiPixel, in.position.xy, u);
    } else if (u.effectMode == 6) {
        color = softFocusGlass(tex, s, sampleUV, radius, uiPixel, in.position.xy, u);
    } else if (u.effectMode == 7) {
        color = voidGlass(tex, s, sampleUV, radius, uiPixel, in.position.xy, u);
    } else {
        color = naturalGlass(tex, s, sampleUV, radius, uiPixel, in.position.xy, u);
    }

    float glass = sine * pow(fromHinge, 1.45);
    float edgeBand = exp(-pow((fromHinge - 0.64) / 0.30, 2.0)) * sine;
    float rim = pow(clamp(1.0 - abs(in.uv.x - 0.5) * 2.0, 0.0, 1.0), 0.25);
    float highlight = edgeBand * (0.020 + 0.085 * u.edgeGlow) * (0.45 + 0.55 * rim);
    color += float3(0.72, 0.90, 1.0) * highlight;

    float reflection = exp(-pow((fromHinge - 0.70) / 0.32, 2.0)) * sine;
    color += float3(0.86, 0.93, 1.0) * reflection * (0.032 * u.reflectionIntensity);
    color *= 1.0 - 0.15 * glass * clamp(u.darknessStrength, 0.0, 2.0);

    color = tone(color, u);

    float fadeDistance = clamp((fromHinge - 0.18) / 0.82, 0.0, 1.0);
    float voidAmount = pow(turn, 1.10) * fadeDistance;
    color *= 1.0 - clamp(0.72 * u.darknessStrength, 0.0, 1.0) * voidAmount;

    if (u.effectMode == 7) {
        color *= 1.0 - smoothstep(0.28, 0.98, turn) * 0.34;
    }

    float sideSoftness = fwidth(in.uv.x) + radius * 0.0018;
    float mask = 1.0 - smoothstep(0.5 - sideSoftness, 0.5 + sideSoftness, abs(plane.x - 0.5));
    float finalClose = 1.0 - smoothstep(0.90, 1.0, turn);

    return float4(mix(DARK, color, mask * finalClose), 1.0);
}
