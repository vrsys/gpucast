#ifndef GPUCAST_ADJOINT_GLSL
#define GPUCAST_ADJOINT_GLSL

/*********************************************************************
 * adjunct of matrix
 *********************************************************************/
mat2
adjoint(in mat2 a) {
  mat2 b;
  b[0][0] =  a[1][1];
  b[0][1] = -a[0][1];
  b[1][0] = -a[1][0];
  b[1][1] =  a[0][0];
  return b;
}

#endif