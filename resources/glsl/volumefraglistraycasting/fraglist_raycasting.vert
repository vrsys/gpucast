/********************************************************************************
* 
* Copyright (C) 2007-2010 Bauhaus-Universitaet Weimar                                               
*
*********************************************************************************
*
*  module     : volumefraglistraycasting/fraglist_raycasting.vert
*  project    : gpucast 
*  description: 
*
********************************************************************************/
#extension GL_NV_gpu_shader5 : enable

/********************************************************************************
* attributes
********************************************************************************/
layout (location = 0) in vec4 in_vertex;
layout (location = 1) in vec4 in_texcoord;


/********************************************************************************
* uniforms
********************************************************************************/

/********************************************************************************
* output
********************************************************************************/
out vec4 fragment_texcoord;

/********************************************************************************
* vertex program for raycasting bezier volumes
********************************************************************************/
void main(void)
{
  fragment_texcoord = in_texcoord;
  gl_Position       = in_vertex;
}

