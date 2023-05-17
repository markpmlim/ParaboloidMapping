// To render a cubemap texture to an offscreen frame buffer
// Created by Mark Lim Pak Mun on 16 May 2023

#if __VERSION__ >= 140

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aTexCoord;

out vec3 objectPos;

#else

attribute vec3 aPos;
attribute vec3 aNormal;
attribute vec2 aTexCoord;

varying vec3 objectPos;

#endif

// Assumes the modelMatrix is an identity matrix.
uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;

void main()
{
    // Pass the vertex's position attribute to the fragment shader.
    objectPos = aPos;
    gl_Position = projectionMatrix * viewMatrix * vec4(aPos, 1.0);
}
