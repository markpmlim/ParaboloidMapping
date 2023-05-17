// Created by Mark Lim Pak Mun on 16 May 2023

#ifdef GL_ES
precision mediump float;
#endif

#if __VERSION__ >= 140
in vec2 texCoords;

out vec4 FragColor;

#else

varying vec2 texCoords;

#endif

uniform sampler2D image;

// Note: The graphic images written out to disk are
// the same as those displayed by Apple's OpenGL Profiler.
void main(void)
{
    // However, we need to flip vertically so that the onscreen display
    // matches the graphic images written out to disk.
    vec2 uv = vec2(texCoords.x, 1.0-texCoords.y);

#if __VERSION__ >= 140
    FragColor = texture(image, uv);
#else
    gl_FragColor = texture2D(image, uv);
#endif
}
