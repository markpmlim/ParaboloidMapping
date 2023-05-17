/*
 A simple fragment shader which accepts the interpolated position of
 a corner of a cube..
 Created by Mark Lim Pak Mun on 16 May 2023
 */
#ifdef GL_ES
precision mediump float;
#endif

#if __VERSION__ >= 140

in vec3 objectPos;

out vec4 FragColor;

#else

varying vec3 objectPos;


#endif

uniform samplerCube cubemapTexture;

#define SRGB_ALPHA 0.055

float linear_from_srgb(float x)
{
    if (x <= 0.04045)
        return x / 12.92;
    else
        return pow((x + SRGB_ALPHA) / (1.0 + SRGB_ALPHA), 2.4);
}

vec3 linear_from_srgb(vec3 rgb)
{
    return vec3(linear_from_srgb(rgb.r),
                linear_from_srgb(rgb.g),
                linear_from_srgb(rgb.b));
}

/*
 The six 2D textures of the cubemap should be flipped vertically when
 viewed with Apple's OpenGL Profiler.
 */
void main()
{
    vec3 direction = normalize(vec3(objectPos.x, objectPos.y, objectPos.z));
    
#if __VERSION__ >= 140
    FragColor = texture(cubemapTexture, direction);
#else
    gl_FragColor = textureCube(cubemapTexture, direction);
#endif
}
