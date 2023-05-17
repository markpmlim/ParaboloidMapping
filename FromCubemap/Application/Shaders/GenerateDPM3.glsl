//
//  Generate a dual paraboloid map from a cubemap
//
//  Generate a dual paraboloid map from a cubemap
//
// Created by Mark Lim Pak Mun on 16 May 2023
//

#ifdef GL_ES
precision mediump float;
#endif

uniform samplerCube cubemap;

in vec2 texCoords;

layout (location = 0) out vec4 fragColor0;  // front side: ColorAttchment0
layout (location = 1) out vec4 fragColor1;  // back side : ColorAttchment1

// We need the Texture Wrapping Mesh to construct a Dual-Paraboloid Map.
// There are 2 circular paraboloids whose equations are:
//  z = 1/2 - 1/2(x^2 + y^2) and
//  z = -1/2 + 1/2(x^2 + y^2)
// They can be re-written as
//  z = 1/2(1 - x^2 - y^2) and
//  z = 1/2(-1 + x^2 + y^2)
void main()
{
    // [0.0, 1.0] --> [-1.0, 1.0]
    vec2 uv = 2.0*texCoords - 1.0;
    
    float s, t;
    s = uv.x;
    t = uv.y;           // do we need to flip horizontally?

    // Compute the reflection vector.
    vec3 R = vec3(0.0);

    float magnitude = s*s + t*t + 1.0;
    // s*s + t*t = 1.0 is the equation of a circle of unit radius
    // centre (0, 0)
    // We are only interested in fragments/pixels that lie within the circle
    // or on the circumference of the circle. And the range of values for
    // the magnitude is [1.0, 2.0]
    if ((s*s + t*t) <= 1.0) {
        // Do the front side first.
        R.x = 2.0*s/magnitude;
        R.y = 2.0*t/magnitude;
        R.z = (1.0 - s*s - t*t)/magnitude;
        // Set alpha to 1.0
        fragColor0 = vec4(texture(cubemap, R).rgb, 1.0);

        // Now do the back side.
        R.x = 2.0*s/magnitude;
        R.y = 2.0*t/magnitude;
        R.z = (s*s + t*t -1.0)/magnitude;
        // Set alpha to 1.0
        fragColor1 = vec4(texture(cubemap, R).rgb, 1.0);
    }
    else {
        // Set alpha to 0.0
        fragColor0 = vec4(0.0, 0.0, 0.0, 0.0);
        fragColor1 = vec4(0.0, 0.0, 0.0, 0.0);
    }
}
