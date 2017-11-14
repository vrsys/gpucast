/********************************************************************************
*
* Copyright (C) 2007-2010 Bauhaus-Universitaet Weimar
*
*********************************************************************************
*
*  module     : raygeneration.frag
*  project    : gpucast
*  description:
*
********************************************************************************/
#extension GL_NV_gpu_shader5 : enable

/********************************************************************************
* constants
********************************************************************************/

/********************************************************************************
* uniforms
********************************************************************************/

/********************************************************************************
* input
********************************************************************************/
in vec4 frag_position;

/********************************************************************************
* output
********************************************************************************/
layout (location = 0) out vec4 out_color;

/********************************************************************************
* functions
********************************************************************************/
void main(void)
{
  out_color = vec4(frag_position.xyz, 1.0f);
}
