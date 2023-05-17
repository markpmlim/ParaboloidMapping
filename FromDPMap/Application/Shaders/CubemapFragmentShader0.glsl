//
//  Generate a cubemap from a dual paraboloid map
//
// Created by Mark Lim Pak Mun on 16 May 2023
//

#ifdef GL_ES
precision mediump float;
#endif

#if __VERSION__ >= 140

in vec3 objectPos;

out vec4 fragColor;

#else

varying vec3 objectPos;

#endif

uniform sampler2D frontImage;
uniform sampler2D backImage;

void main()
{
    // Interpolated position attribute of a vertex
    vec3 R = normalize(objectPos);
    float s, t;

    // It seems the set of instructions need to be swap to
    // project the dual paraboloid map to a cubemap.
    if (R.z < 0.0) {
        // original instructions as per NVidia's slide
        s = -R.x/(1.0 + R.z);
        t = -R.y/(1.0 + R.z);

        // The s, t texcoordinates should be in the range [-1.0, 1.0]
        vec2 uv = vec2(s, t);
        // Re-map their range to [0.0, 1.0]
        uv = (uv + 1.0)/2.0;
        fragColor = vec4(texture(backImage, uv).rgb, 1.0);
     }
     else {
         // original instructions as per NVidia's slide
         s = R.x/(1.0 - R.z);
         t = R.y/(1.0 - R.z);

         // The s, t texcoordinates should be in the range [-1.0, 1.0]
         vec2 uv = vec2(s, t);
         // Re-map their range to [0.0, 1.0]
         uv = (uv + 1.0)/2.0;
         fragColor = texture(frontImage, uv);
     }
}
