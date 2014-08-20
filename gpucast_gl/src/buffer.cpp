/********************************************************************************
*
* Copyright (C) 2009-2010 Bauhaus-Universitaet Weimar
*
*********************************************************************************
*
*  module     : buffer.cpp
*  project    : glpp
*  description:
*
********************************************************************************/
#include "gpucast/gl/buffer.hpp"

// header system
#include <vector>
#include <iostream>
#include <exception>

// header dependencies
#include <GL/glew.h>

// header project
#include <gpucast/gl/math/vec4.hpp>
#include <gpucast/gl/error.hpp>

namespace gpucast { namespace gl {

///////////////////////////////////////////////////////////////////////////////
buffer::buffer(GLenum usage)
: _id       ( 0 ),
  _usage    ( usage ),
  _capacity ( 0 )
{
  glGenBuffers (1, &_id);
}


///////////////////////////////////////////////////////////////////////////////
buffer::buffer( std::size_t bytes, GLenum usage )
: _id       ( 0 ),
  _usage    ( usage ),
  _capacity ( bytes )
{
  glGenBuffers( 1, &_id );
  bufferdata  ( bytes, 0 );
}


///////////////////////////////////////////////////////////////////////////////
buffer::~buffer()
{
#if 0
  std::cout << "entering buffer::~buffer( )" << std::endl;
  error("gl error? : ");

  std::cout << "Buffer ID ? : " << _id << std::endl;
  std::cout << "glIsBuffer? : " << (glIsBuffer(_id) == GL_TRUE) << std::endl;

  std::cout << "access ? : " << parameter( GL_BUFFER_ACCESS ) << std::endl;
  std::cout << "mapped ? : " << parameter( GL_BUFFER_MAPPED ) << std::endl;
  std::cout << "size ?   : " << parameter( GL_BUFFER_SIZE ) << std::endl;
  std::cout << "usage ?  : " << parameter( GL_BUFFER_USAGE )<< std::endl;
#endif
  glDeleteBuffers(1, &_id);
}


///////////////////////////////////////////////////////////////////////////////
void            
buffer::swap( buffer& t)
{
  std::swap ( _id,        t._id );
  std::swap ( _usage,     t._usage );
  std::swap ( _capacity,  t._capacity );
}


///////////////////////////////////////////////////////////////////////////////
void 
buffer::bufferdata( std::size_t   bytes,
                    GLvoid const* data,
                    GLenum        usage )
{
  _usage = usage;

#if GPUCAST_GL_DIRECT_STATE_ACCESS
  glNamedBufferDataEXT(_id, bytes, data, _usage);
#else
  glBindBuffer (target(), _id);
  glBufferData (target(), GLuint(bytes), data, _usage);
#endif
  _capacity = bytes;
}


///////////////////////////////////////////////////////////////////////////////
void 
buffer::buffersubdata( std::size_t    offset_bytes,
                       std::size_t    bytes,
                       GLvoid const*  data ) const
{
  assert(offset_bytes + bytes <= _capacity);
#if GPUCAST_GL_DIRECT_STATE_ACCESS
  glNamedBufferSubDataEXT(_id, offset_bytes, bytes, data);
#else
  glBindBuffer   (target(), _id);
  glBufferSubData(target(), GLintptrARB(offset_bytes), GLintptrARB(bytes), data);
#endif
}


///////////////////////////////////////////////////////////////////////////////
void            
buffer::getbuffersubdata ( GLintptr     offset,
                           GLsizeiptr   size,
                           GLvoid*      data ) const
{
#if GPUCAST_GL_DIRECT_STATE_ACCESS
  glGetNamedBufferSubDataEXT(_id, offset, size, data);
#else
  throw std::runtime_error("buffer::getbuffersubdata() only implemented with DSA.");
#endif
}


///////////////////////////////////////////////////////////////////////////////
GLuint64EXT            
buffer::address () const
{
  GLuint64EXT device_address;
  glGetBufferParameterui64vNV(target(), GL_BUFFER_GPU_ADDRESS_NV, &device_address); 
  return device_address;
}


///////////////////////////////////////////////////////////////////////////////
GLuint          
buffer::id( ) const
{
  return _id;
}

///////////////////////////////////////////////////////////////////////////////
GLenum          
buffer::usage ( ) const
{
  return _usage;
}

///////////////////////////////////////////////////////////////////////////////
std::size_t
buffer::capacity ( ) const
{
  return _capacity;
}


///////////////////////////////////////////////////////////////////////////////
GLint           
buffer::parameter ( GLenum parameter ) const
{
 #if GPUCAST_GL_DIRECT_STATE_ACCESS
  GLint value;
  glGetNamedBufferParameterivEXT( _id, parameter, &value);
  return value;
#else
  throw std::runtime_error("buffer::parameter() only implemented with DSA.");
#endif
}


///////////////////////////////////////////////////////////////////////////////
void*           
buffer::map ( GLenum access ) const
{
#if GPUCAST_GL_DIRECT_STATE_ACCESS
  return glMapNamedBufferEXT(_id, access);
#else
  throw std::runtime_error("buffer::map() only implemented with DSA.");
#endif
}


///////////////////////////////////////////////////////////////////////////////
void*           
buffer::map_range ( GLintptr offset, GLsizeiptr  length, GLbitfield  access ) const
{
#if GPUCAST_GL_DIRECT_STATE_ACCESS
  return glMapNamedBufferRangeEXT(_id, offset, length, access);
#else
  throw std::runtime_error("buffer::map_range() only implemented with DSA.");
#endif
}


///////////////////////////////////////////////////////////////////////////////
bool buffer::unmap ( ) const
{
#if GPUCAST_GL_DIRECT_STATE_ACCESS
  return glUnmapNamedBufferEXT(_id) ? true : false;
#else
  throw std::runtime_error("buffer::unmap() only implemented with DSA.");
#endif
}

 
///////////////////////////////////////////////////////////////////////////////
void            
buffer::make_resident ( ) const
{
  glMakeBufferResidentNV(target(), GL_READ_ONLY);
}


} } // namespace gpucast / namespace gl