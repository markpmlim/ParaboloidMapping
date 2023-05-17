// Created by Mark Lim Pak Mun on 16 May 2023

#if __VERSION__ >= 140
out vec2 texCoords;

#else
varying vec2 texCoords;
#endif


/*
 To generate the 2 maps, we need a special texture warping mesh.
 We will use the equations outlined in the webpage
 "Advantages and Disadvantages" or NVidia's slide with the
 title "Dual-parabolic Mapping".
 This vertex shader is used to generate the dual-paraboloid map
 as well as display the two textures of the map side-by-side.
 */
void main(void)
{
    float x = float((gl_VertexID & 1) << 2);
    float y = float((gl_VertexID & 2) << 1);
    texCoords = vec2(x * 0.5, y * 0.5);
    gl_Position = vec4(x - 1.0, y - 1.0, 0, 1);
}
