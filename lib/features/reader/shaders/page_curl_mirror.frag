#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform vec4 iMouse;
uniform sampler2D image;

#define pi 3.14159265359
#define radius 0.1
#define shadowWidth 0.05
#define TRANSPARENT vec4(0.0, 0.0, 0.0, 0.0)

out vec4 fragColor;

float calShadow(vec2 targetPoint, float aspect){
    if (targetPoint.y>=1.0){
        return max(pow(clamp((targetPoint.y-1.0)/shadowWidth, 0.0, 0.9), 0.2), pow(clamp((targetPoint.x-aspect)/shadowWidth, 0.0, 0.9), 0.2));
    } else {
        return max(pow(clamp((0.0-targetPoint.y)/shadowWidth, 0.0, 0.9), 0.2), pow(clamp((targetPoint.x-aspect)/shadowWidth, 0.0, 0.9), 0.2));
    }
}

vec2 rotate(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

vec2 pointOnCircle(vec2 center, vec2 startPoint, float currentRadius, float arcLength, bool clockwise) {
    float theta = arcLength / currentRadius;
    vec2 startVec = startPoint - center;
    startVec = normalize(startVec);
    float rotationAngle = clockwise ? -theta : theta;
    vec2 rotatedVec = rotate(startVec, rotationAngle);
    vec2 endPoint = center + rotatedVec * currentRadius;
    return endPoint;
}

void main() {
    // === HORIZONTAL MIRROR LOGIC ===
    // We invert the X coordinate of the fragment and the mouse input.
    // This makes the logic behave as if it's curling from the Right (standard),
    // but visually it processes pixels from the Left.
    
    vec2 fragCoordRaw = FlutterFragCoord().xy;
    // Invert Fragment X
    vec2 fragCoord = vec2(resolution.x - fragCoordRaw.x, fragCoordRaw.y);
    
    float aspect = resolution.x / resolution.y;
    vec2 uv = fragCoord * vec2(aspect, 1.0) / resolution.xy;
    
    // Invert Mouse X
    vec4 currentMouse = vec4(resolution.x - iMouse.x, iMouse.y, resolution.x - iMouse.z, iMouse.w);
    
    // === REUSE ORIGINAL LOGIC BELOW (Variable names kept same) ===
    
    // Determine curl direction: (Inverted logic: if original MouseZ > Width/2, it means RightCurl)
    // But since we inverted MouseZ, a Left Click (Small Z) becomes Big Z in inverted space.
    // So logic holds: We want 'Right Curl Logic' to run.
    bool isRightCurl = (currentMouse.z > resolution.x / 2.0);
    
    float cornerX = isRightCurl ? aspect : 0.0;
    vec2 cornerFrom = vec2(cornerX, (currentMouse.w < resolution.y/2.0) ? 0.0 : 1.0);
    vec2 spineAnchor = vec2(isRightCurl ? 0.0 : aspect, cornerFrom.y==0.0?0.0:1.0);

    // 归一化鼠标坐标
    vec2 mouse = currentMouse.xy * vec2(aspect, 1.0) / resolution.xy;
    
    if (distance(mouse.xy, spineAnchor) > aspect) {
        vec2 startPoint = spineAnchor;
        vec2 vector = normalize(vec2(0.5, 0.5*tan(pi/3.0))); 
        vec2 calcMouse = mouse;
        if (!isRightCurl) calcMouse.x = aspect - calcMouse.x;
        
        vec2 calcStart = vec2(0.0, cornerFrom.y==0.0?0.0:1.0);
        
        vec2 targetMouse = calcMouse;
        vec2 v = targetMouse - calcStart;
        float proj_length = dot(v, vector);
        vec2 targetMouse_proj = calcStart + proj_length*vector;
        
        float base_line_distance = length(targetMouse_proj - targetMouse);
        float arc_distance = distance(targetMouse, calcStart) - aspect;
        float actual_distance = min(abs(base_line_distance), abs(arc_distance));
        
        vec2 currentMouse_arc_proj = calcStart + normalize(calcMouse - calcStart)*aspect;
        vec2 newPoint_arc_proj = pointOnCircle(calcStart, currentMouse_arc_proj, aspect, actual_distance/2.0, calcMouse.y<=tan(pi/3.0)*calcMouse.x);
        
        calcMouse = newPoint_arc_proj;
        
        if (!isRightCurl) calcMouse.x = aspect - calcMouse.x;
        mouse = calcMouse;

        currentMouse.xy = mouse * resolution.xy / vec2(aspect, 1.0);
    }
    
    vec2 mouseDir = normalize(abs(cornerFrom * resolution.xy / vec2(aspect, 1.0)) - currentMouse.xy);
    vec2 origin = clamp(mouse - mouseDir * mouse.x / mouseDir.x, 0.0, 1.0);
    float mouseDist = distance(mouse, origin);
    if (mouseDir.x < 0.0) {
        mouseDist = distance(mouse, origin);
    }
    
    float proj = dot(uv - origin, mouseDir);
    float dist = proj - (mouse.x<0.0 ? -mouseDist : mouseDist);
    
    vec2 curlAxisLinePoint = uv - dist * mouseDir;
    
    float actualDist = distance(mouse, cornerFrom);
    if (actualDist >= pi*radius) {
        float params = (actualDist - pi*radius)/2.0;
        curlAxisLinePoint += params * mouseDir;
        dist -= params;
    }
    
    if (dist > radius) {
        fragColor = vec4(0.0, 0.0, 0.0, (1.0 - pow(clamp((dist - radius)*pi, 0.0, 1.0), 0.2)));
    } else if (dist >= 0.0) {
        float theta = asin(dist / radius);
        vec2 p2 = curlAxisLinePoint + mouseDir * (pi - theta) * radius;
        vec2 p1 = curlAxisLinePoint + mouseDir * theta * radius;
        
        if (p2.x <= aspect && p2.y <= 1.0 && p2.x > 0.0 && p2.y > 0.0) {
            uv = p2;
            // === UN-MIRROR UV FOR SAMPLING ===
            // The calculated uv is in inverted space. We must revert it to sample correct image pixel.
            // Aspect ratio scaling is involved in calculation, but texture lookup expects 0..1
            // Let's normalize first:
            vec2 normUV = uv * vec2(1.0 / aspect, 1.0);
            // Invert X
            normUV.x = 1.0 - normUV.x;
            fragColor = texture(image, normUV);
        } else {
            uv = p1;
            // === UN-MIRROR UV FOR SAMPLING ===
            vec2 normUV = uv * vec2(1.0 / aspect, 1.0);
            normUV.x = 1.0 - normUV.x;
            fragColor = texture(image, normUV);
            
            if (p2.x <= aspect+shadowWidth && p2.y <= 1.0+shadowWidth && p2.x > 0.0-shadowWidth && p2.y > 0.0-shadowWidth) {
                float shadow = calShadow(p2, aspect);
                fragColor = vec4(fragColor.r*shadow, fragColor.g*shadow, fragColor.b*shadow, fragColor.a);
            }
        }
    } else {
        vec2 p = curlAxisLinePoint + mouseDir * (abs(dist) + pi * radius);
        if (p.x <= aspect && p.y <= 1.0 && p.x > 0.0 && p.y > 0.0) {
            uv = p;
            // === UN-MIRROR UV FOR SAMPLING ===
            vec2 normUV = uv * vec2(1.0 / aspect, 1.0);
            normUV.x = 1.0 - normUV.x; // Invert X
            fragColor = texture(image, normUV);
        } else {
            // === UN-MIRROR UV FOR SAMPLING ===
            vec2 normUV = uv * vec2(1.0 / aspect, 1.0);
            normUV.x = 1.0 - normUV.x; // Invert X
            fragColor = texture(image, normUV);
            
            if (p.x <= aspect+shadowWidth && p.y <= 1.0+shadowWidth && p.x > 0.0-shadowWidth && p.y > 0.0-shadowWidth) {
                float shadow = calShadow(p, aspect);
                fragColor = vec4(fragColor.r*shadow, fragColor.g*shadow, fragColor.b*shadow, fragColor.a);
            }
        }
    }
}
