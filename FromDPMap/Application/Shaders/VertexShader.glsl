/*
 A simple vertex shader which passes the position of a corner
 of a cube to a fragment shader.

 Created by Mark Lim Pak Mun on 16 May 2023
 */
#ifdef GL_ES
precision mediump float;
#endif

in vec3 aPos;

uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

#if __VERSION__ >= 140

out vec3 objectPos;

#else

varying vec3 objectPos;

#endif

void main()
{
    objectPos = aPos;

	vec4 clipPos = projectionMatrix * viewMatrix * modelMatrix * vec4(aPos, 1.0);
	gl_Position = clipPos;
}
