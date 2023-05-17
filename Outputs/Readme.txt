A dual-paraboloid map consist of two 2D textures. These 2 textures can be output to disk as separate images or a single image.

The program DPMapFromCubemap-macOS saves the projected dual-paraboloid map as 2 separate graphic images named Front.png and Back.png in the user's Document folder. These are then copied to the Images folder of the project to be imported by the 2nd program CubemapFromDPMap-macOS into its Resources folder.

For your convenience and reference, we have saved a total of 4 dual-paraboloid maps as 8 separate files. The files are renamed from Front.png and Back.png to Frontx.png and Backx.png and copied to the Output folder.


Frontx.png and Backx.png are generated using the fragment shader GenerateDPMx.glsl where x = 0, 1, 2, 3.

To test the reverse mapping, if GenerateDPM2.glsl was used by the first program, then the second program must use CubemapFragmentShader2.glsl as its fragment shader.