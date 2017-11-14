/********************************************************************************
* 
* Copyright (C) 2007-2010 Bauhaus-Universitaet Weimar                                               
*
*********************************************************************************
*
*  module     : raycast_sampled_volume.glsl.vert                             
*  project    : gpucast 
*  description: 
*
********************************************************************************/
#extension GL_NV_gpu_shader5 : enable

/********************************************************************************
* attributes
********************************************************************************/
layout (location = 0) in vec4 vertex;
layout (location = 1) in vec4 color;

/********************************************************************************
* uniforms
********************************************************************************/
uniform mat4 modelviewprojectionmatrix;

/********************************************************************************
* output
********************************************************************************/
out vec4 fragcolor;

/********************************************************************************
* vertex program for raycasting bezier volumes
********************************************************************************/
void main(void)
{
  fragcolor = color; 

  // transform vertex to screen for fragment generation
  gl_Position  = modelviewprojectionmatrix * vertex;

}

