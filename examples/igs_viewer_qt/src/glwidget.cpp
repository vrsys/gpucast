/********************************************************************************
*
* Copyright (C) 2010 Bauhaus University Weimar
*
*********************************************************************************
*
*  module     : glwidget.cpp
*  project    : glpp
*  description:
*
********************************************************************************/
#include "glwidget.hpp"

#pragma warning(disable: 4127) // Qt conditional expression is constant

#include <mainwindow.hpp>

// system includes
#include <QtGui/QMouseEvent>
#include <QtOpenGL/QGLFormat>

#include <sstream>
#include <iostream>
#include <cctype>
#include <typeinfo>

#include <gpucast/gl/fragmentshader.hpp>
#include <gpucast/gl/vertexshader.hpp>
#include <gpucast/gl/util/init_glew.hpp>
#include <gpucast/gl/util/timer.hpp>
#include <gpucast/gl/util/vsync.hpp>
#include <gpucast/gl/error.hpp>

#include <gpucast/math/parametric/point.hpp>
#include <gpucast/math/parametric/beziercurve.hpp>
#include <gpucast/math/parametric/beziersurface.hpp>
#include <gpucast/math/parametric/beziervolume.hpp>
#include <gpucast/math/parametric/nurbsvolume.hpp>

#include <gpucast/core/beziersurfaceobject.hpp>
#include <gpucast/core/nurbssurfaceobject.hpp>
#include <gpucast/core/surface_converter.hpp>
#include <gpucast/core/import/igs_loader.hpp>

#include <boost/bind.hpp>
#include <boost/foreach.hpp>
#include <boost/algorithm/string/case_conv.hpp>
#include <boost/filesystem.hpp>


#define FXAA_ANTIALIASING

///////////////////////////////////////////////////////////////////////
glwidget::glwidget( int argc, char** argv, QGLFormat const& context_format, QWidget *parent)
 :  QGLWidget         ( context_format, parent),
    _argc             ( argc ),
    _argv             ( argv ),
    _initialized      ( false ),
    _frames           ( 0 ),
    _time             ( 0.0 ),
    _background       ( 0.2f, 0.2f, 0.2f ),
    _fxaa             ( false ),
    _ambient_occlusion( false ),
    _aoradius         ( 30.0f ),
    _aosamples        ( 500 ) 
{
  setFocusPolicy(Qt::StrongFocus);
}


///////////////////////////////////////////////////////////////////////
glwidget::~glwidget()
{}


///////////////////////////////////////////////////////////////////////
void                
glwidget::open ( std::list<std::string> const& files )
{  
  _trackball->reset();
  if ( files.empty() ) return;

  // clear old objects
  _objects.clear();

  // open file(s) and set new boundingbox
  std::for_each(files.begin(), files.end(), [&] ( std::string const& file ) {
                                                                              gpucast::math::axis_aligned_boundingbox<gpucast::math::point3d> bbox;
                                                                              _openfile(file, bbox);
                                                                              std::cout << "Opening " << file << " : Bbox = " << bbox << std::endl;

                                                                              if ( file == files.front() ) 
                                                                              {
                                                                                _boundingbox = bbox; // reset bounding box
                                                                              } else {
                                                                                _boundingbox.merge(bbox); // extend bounding box
                                                                              }
                                                                            } );
  //_openfile ( file, _boundingbox );
}


///////////////////////////////////////////////////////////////////////
void                
glwidget::add ( std::list<std::string> const& files )
{ 
  if ( files.empty() ) return;

  std::for_each(files.begin(), files.end(), [&] ( std::string const& file ) 
                                                  {
                                                    // create temporary new bounding box of added objects
                                                    gpucast::math::axis_aligned_boundingbox<gpucast::math::point3d> bbox;
                                                    _openfile ( file, bbox );
                                                    _boundingbox.merge ( bbox );
                                                  } );
}



///////////////////////////////////////////////////////////////////////
void                
glwidget::recompile ( )
{
  gpucast::gl::bezierobject_renderer::instance().recompile();
  gpucast::gl::bezierobject_renderer::instance().init_program(_fbo_program, "./gpucast_core/glsl/base/render_from_texture_sao.vert", "./gpucast_core/glsl/base/render_from_texture_sao.frag");
}


///////////////////////////////////////////////////////////////////////
void glwidget::initializeGL()
{
  glEnable(GL_DEPTH_TEST);
}


///////////////////////////////////////////////////////////////////////
void 
glwidget::resizeGL(int width, int height)
{
  _width  = width;
  _height = height;

  if (!_initialized) 
    return;
  
  glViewport(0, 0, GLsizei(_width), GLsizei(_height));

  // if renderer already initialized -> resize
  _colorattachment.reset(new gpucast::gl::texture2d);
  _colorattachment->teximage(0, GL_RGBA32F, GLsizei(_width), GLsizei(_height), 0, GL_RGBA, GL_FLOAT, 0);

  _depthattachment.reset(new gpucast::gl::texture2d);
  _depthattachment->teximage(0, GL_DEPTH32F_STENCIL8 , GLsizei(_width), GLsizei(_height), 0, GL_DEPTH_COMPONENT, GL_FLOAT, 0);

  _fbo.reset(new gpucast::gl::framebufferobject);
  _fbo->attach_texture (*_colorattachment, GL_COLOR_ATTACHMENT0_EXT);
  _fbo->attach_texture (*_depthattachment, GL_DEPTH_STENCIL_ATTACHMENT);

  _fbo->bind();
  _fbo->status();
  _fbo->unbind();
  _generate_random_texture();
}


///////////////////////////////////////////////////////////////////////
void 
glwidget::paintGL()
{
#define FBO 1

  // draw pre-evaluated stuff... 
  if (!_initialized)
  {
    // init data, buffers and shader
    _init();
    _initialized = true;

    // try to update main widget
    mainwindow* mainwin = dynamic_cast<mainwindow*>(parent());
    if (mainwin) {
      mainwin->update_interface();
    } else {
      std::cerr << "glwidget::paintGL(): Could not cast to mainwindow widget" << std::endl;
    }
  }

  gpucast::gl::timer t;
  t.start();

#if FBO
  _fbo->bind();
#endif

  glEnable(GL_DEPTH_TEST);

  glClearColor(_background[0], _background[1], _background[2], 1.0f);
  glClearDepth(1.0f);
  
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
  
  float nearplane = 0.01f * _boundingbox.size().abs();
  float farplane  = 2.0f  * _boundingbox.size().abs();

  auto& renderer = gpucast::gl::bezierobject_renderer::instance();
  renderer.set_nearfar(nearplane, farplane);

  gpucast::gl::matrix4f view = gpucast::gl::lookat(0.0f, 0.0f, float(_boundingbox.size().abs()), 
                                     0.0f, 0.0f, 0.0f, 
                                     0.0f, 1.0f, 0.0f);

  gpucast::gl::vec3f translation = _boundingbox.center();

  gpucast::gl::matrix4f model    = gpucast::gl::make_translation(_trackball->shiftx(), _trackball->shifty(), 
                                   _trackball->distance()) *_trackball->rotation() * 
                                   gpucast::gl::make_translation(-translation[0], -translation[1], -translation[2]);

  gpucast::gl::matrix4f proj = gpucast::gl::perspective(60.0f, float(_width) / _height, nearplane, farplane); 
  gpucast::gl::matrix4f mv   = view * model;
  gpucast::gl::matrix4f mvp  = proj * mv;
  gpucast::gl::matrix4f mvpi = gpucast::gl::inverse(mvp);

  renderer.projectionmatrix(proj);
  renderer.modelviewmatrix(mv);

  for (auto const& o : _objects)
  {
    o->draw();
  }

  glFinish(); 

#if FBO

  _fbo->unbind();

  ++_frames;

  // pass fps to window
  t.stop();
  gpucast::gl::time_duration elapsed = t.result();
  double drawtime_seconds = elapsed.fractional_seconds + elapsed.seconds; // discard minutes
  _time += drawtime_seconds;

  // show message and reset counter if more than 1s passed
  if ( _time > 0.5 || _frames > 20 ) 
  {
    mainwindow* mainwin = dynamic_cast<mainwindow*>(parent());
    if (mainwin) 
    {
      mainwin->show_fps ( double(_frames) / _time );
    }
    _frames = 0;
    _time   = 0.0;
  }

  // render into drawbuffer
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
  _fbo_program->begin();
  
  _fbo_program->set_uniform_matrix4fv ("modelviewprojectioninverse", 1, false, &mvpi[0]);
  _fbo_program->set_uniform_matrix4fv ( "modelviewprojection", 1,       false, &mvp[0]);

  _fbo_program->set_texture2d         ( "colorbuffer",       *_colorattachment,   1);
  _fbo_program->set_texture2d         ( "depthbuffer",       *_depthattachment,   2);
  _fbo_program->set_texture2d         ( "random_texture",    *_aorandom_texture,  3);
  _fbo_program->set_texturebuffer     ( "ao_sample_offsets", *_aosample_offsets,  4);  

  _sample_linear->bind(1);
  _sample_linear->bind(2);
  _sample_nearest->bind(3);

  _fbo_program->set_uniform1i         ( "ao_enable",         int(_ambient_occlusion) );
  _fbo_program->set_uniform1i         ( "ao_samples",        _aosamples );
  _fbo_program->set_uniform1f         ( "ao_radius",         _aoradius );
  _fbo_program->set_uniform1i         ( "fxaa",              int(_fxaa) );
  
  _fbo_program->set_uniform1i         ( "width",             GLsizei(_width));
  _fbo_program->set_uniform1i         ( "height",            GLsizei(_height));
  _quad->draw();
  
  _fbo_program->end();
#endif

  // redraw
  this->update();
}


///////////////////////////////////////////////////////////////////////
void 
glwidget::mousePressEvent(QMouseEvent *event)
{
  enum gpucast::gl::eventhandler::button b;

  switch (event->button()) {
    case Qt::MouseButton::LeftButton    : b = gpucast::gl::eventhandler::left; break;
    case Qt::MouseButton::RightButton   : b = gpucast::gl::eventhandler::right; break;
    case Qt::MouseButton::MiddleButton  : b = gpucast::gl::eventhandler::middle; break;
    default : return;
  }

  _trackball->mouse(b, gpucast::gl::eventhandler::press, event->x(), event->y());
}


///////////////////////////////////////////////////////////////////////
void 
glwidget::mouseReleaseEvent(QMouseEvent *event)
{
  enum gpucast::gl::eventhandler::button b;

  switch (event->button()) {
    case Qt::MouseButton::LeftButton    : b = gpucast::gl::eventhandler::left; break;
    case Qt::MouseButton::RightButton   : b = gpucast::gl::eventhandler::right; break;
    case Qt::MouseButton::MiddleButton  : b = gpucast::gl::eventhandler::middle; break;
    default : return;
  }

  _trackball->mouse(b, gpucast::gl::trackball::release, event->x(), event->y());
}


///////////////////////////////////////////////////////////////////////
void 
glwidget::mouseMoveEvent(QMouseEvent *event)
{
  _trackball->motion(event->x(), event->y());
}



///////////////////////////////////////////////////////////////////////
/* virtual */ void  
glwidget::keyPressEvent ( QKeyEvent* /*event*/)
{}


///////////////////////////////////////////////////////////////////////
/* virtual */ void  
glwidget::keyReleaseEvent ( QKeyEvent* event )
{
  char key = event->key();

  if (event->modifiers() != Qt::ShiftModifier) {
    key = std::tolower(key);
  }

  switch (key)
  {
    case 'r':
      gpucast::gl::bezierobject_renderer::instance().recompile();
      break;
  }


  for ( auto const& o : _objects) 
  {
    switch (key)
    {
      case 'I':
        o->max_newton_iterations(o->max_newton_iterations() + 1);
        break;
      case 'i':
        o->max_newton_iterations(std::max(1U, o->max_newton_iterations() - 1));
        break;
      case 't':
        o->trimming(!o->trimming());
        break;
      case 'n':
        o->raycasting(!o->raycasting());
        break;
      case 'b':
        o->culling(!o->culling());
        break;
      default:
        break;// do nothing 
    }
  }
}



///////////////////////////////////////////////////////////////////////
  void                    
  glwidget::load_spheremap                ( )
  {
    QString in_image_path = QFileDialog::getOpenFileName(this, tr("Open Image"), ".", tr("Image Files (*.jpg *.jpeg *.hdr *.bmp *.png *.tiff *.tif)"));
    gpucast::gl::bezierobject_renderer::instance().spheremap(in_image_path.toStdString());
  }


  ///////////////////////////////////////////////////////////////////////
  void                    
  glwidget::load_diffusemap               ( )
  {
    QString in_image_path = QFileDialog::getOpenFileName(this, tr("Open Image"), ".", tr("Image Files (*.jpg *.jpeg *.hdr *.bmp *.png *.tiff *.tif)"));
    gpucast::gl::bezierobject_renderer::instance().diffusemap(in_image_path.toStdString());
  }


  ///////////////////////////////////////////////////////////////////////
  void glwidget::spheremapping(int)
  {}

  ///////////////////////////////////////////////////////////////////////
  void glwidget::diffusemapping(int)
  {}

  ///////////////////////////////////////////////////////////////////////
  void                      
  glwidget::fxaa                          ( int i )
  {
    _fxaa = i;
  }

  
  ///////////////////////////////////////////////////////////////////////
  void                      
  glwidget::vsync                          ( int i )
  {
    gpucast::gl::set_vsync(i != 0);
  }



  ///////////////////////////////////////////////////////////////////////
  void                      
  glwidget::ambient_occlusion             ( int i )
  {
    _ambient_occlusion = i;
  }




///////////////////////////////////////////////////////////////////////
void
glwidget::_init()
{
  gpucast::gl::init_glew ();
  _print_contextinfo();

  auto& renderer = gpucast::gl::bezierobject_renderer::instance();

  renderer.add_search_path("../../../");
  renderer.add_search_path("../../");
  renderer.recompile();

  _trackball.reset       ( new gpucast::gl::trackball );

  _fbo.reset             ( new gpucast::gl::framebufferobject );
  _depthattachment.reset ( new gpucast::gl::texture2d );
  _colorattachment.reset ( new gpucast::gl::texture2d );
  _aorandom_texture.reset( new gpucast::gl::texture2d );
  _aosample_offsets.reset( new gpucast::gl::texturebuffer );
  _quad.reset            ( new gpucast::gl::plane(0, -1, 1) );

  _sample_linear.reset   ( new gpucast::gl::sampler );
  _sample_linear->parameter(GL_TEXTURE_WRAP_S, GL_CLAMP);
  _sample_linear->parameter(GL_TEXTURE_WRAP_T, GL_CLAMP);
  _sample_linear->parameter(GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  _sample_linear->parameter(GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  _sample_nearest.reset  ( new gpucast::gl::sampler );
  _sample_nearest->parameter(GL_TEXTURE_WRAP_S, GL_CLAMP);
  _sample_nearest->parameter(GL_TEXTURE_WRAP_T, GL_CLAMP);
  _sample_nearest->parameter(GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  _sample_nearest->parameter(GL_TEXTURE_MAG_FILTER, GL_NEAREST);

  _generate_random_texture();
  _generate_ao_sampletexture();

  _fbo_program.reset ( new gpucast::gl::program );

  recompile();
}


///////////////////////////////////////////////////////////////////////
void                    
glwidget::_generate_ao_sampletexture ()
{
  std::vector<float> offsets(4 * TOTAL_RANDOM_SAMPLES); // 8 x random_access, 4 elements per offset * samples
  gpucast::gl::time_duration t0;
  gpucast::gl::timer t;
  t.time(t0);
  std::srand(unsigned(t0.fractional_seconds*1000.0));
  
  std::generate(offsets.begin(), offsets.end(), [&] () { return 2.0f * (std::rand()/float(RAND_MAX) - 0.5f); } );
  _aosample_offsets->update(offsets.begin(), offsets.end());
  _aosample_offsets->format(GL_RGBA32F);
}


///////////////////////////////////////////////////////////////////////
void
glwidget::_generate_random_texture()
{
  std::vector<unsigned> random_values ( _width * _height );
  std::generate (random_values.begin(), random_values.end(), [&] () { return std::rand()%(TOTAL_RANDOM_SAMPLES - _aosamples); } );
  _aorandom_texture->teximage(0, GL_R32I, int(_width), int(_height), 0, GL_RED_INTEGER, GL_UNSIGNED_INT, &random_values[0]);
}


///////////////////////////////////////////////////////////////////////
void
glwidget::_print_contextinfo()
{
  char* gl_version   = (char*)glGetString(GL_VERSION);
  char* glsl_version = (char*)glGetString(GL_SHADING_LANGUAGE_VERSION);

  GLint context_profile;
  glGetIntegerv(GL_CONTEXT_PROFILE_MASK, &context_profile);

  std::cout << "OpenGL Version String : " << gl_version << std::endl;
  std::cout << "GLSL Version String   : " << glsl_version << std::endl;

  switch (context_profile) {
    case GL_CONTEXT_CORE_PROFILE_BIT :
      std::cout << "Core Profile" << std::endl; break;
    case GL_CONTEXT_COMPATIBILITY_PROFILE_BIT :
      std::cout << "Compatibility Profile" << std::endl; break;
    default :
      std::cout << "Unknown Profile" << std::endl;
  };
}


///////////////////////////////////////////////////////////////////////
void                    
glwidget::_openfile ( std::string const& file, gpucast::math::axis_aligned_boundingbox<gpucast::math::point3d>& bbox )
{
  gpucast::igs_loader         igsloader;
  gpucast::surface_converter  nurbsconverter;
  std::string                 extension = boost::filesystem::extension(file);

  if ( extension == ".igs" )
  { 
    auto nurbsobject = igsloader.load(file);

    auto bezierobject = std::make_shared<gpucast::beziersurfaceobject>();
    nurbsconverter.convert(nurbsobject, bezierobject);

    bezierobject->init();

    gpucast::gl::material mat;
    mat.randomize(0.05f, 1.0f, 0.1f, 20.0f, 1.0f);

    auto drawable = std::make_shared<gpucast::gl::bezierobject>(*bezierobject);
    drawable->set_material(mat);

    _objects.push_back(drawable);

    bbox = bezierobject->bbox();
  }

  if ( extension == ".cfg" )
  {
    std::ifstream ifstr(file.c_str());
    typedef std::vector<std::pair<gpucast::gl::material, std::string> > file_map_t;
    file_map_t filemap;
    gpucast::gl::material current_material;

    if (ifstr.good()) 
    {
      std::string line;
      while (ifstr) 
      {
        std::getline(ifstr, line);

        if (!line.empty()) 
        {
          std::istringstream sstr(line);
          std::string qualifier;
          sstr >> qualifier;

          // if not comment line
          if (qualifier.size() > 0) 
          {
            if (qualifier.at(0) != '#') 
            {
              // define material
              if (qualifier == "material") 
              {
                _parse_material_conf(sstr, current_material);
              }
              // load igs file
              if (qualifier == "object") 
              {
                if (sstr) 
                {
                  std::string filename;
                  sstr >> filename;
                  filemap.push_back(std::make_pair(current_material, filename));
                }
              }
              if (qualifier == "background") 
              {
                if (sstr) {
                  _parse_background(sstr, _background);
                }
              }
            }
          }
        }
      }
    }

    for (file_map_t::iterator i = filemap.begin(); i != filemap.end(); ++i) 
    {
      auto nurbsobject = igsloader.load(i->second);

      auto bezierobject = std::make_shared<gpucast::beziersurfaceobject>();
      nurbsconverter.convert(nurbsobject, bezierobject);

      bezierobject->init();

      auto drawable = std::make_shared<gpucast::gl::bezierobject>(*bezierobject);
      drawable->set_material(i->first);
      bbox = bezierobject->bbox();

      _objects.push_back(drawable);

      if ( i == filemap.begin() )
      { 
        bbox = bezierobject->bbox();
      } else {
        bbox.merge(bezierobject->bbox());
      }
    }

    ifstr.close();
  }
}


///////////////////////////////////////////////////////////////////////////////
void
glwidget::_parse_material_conf(std::istringstream& sstr, gpucast::gl::material& mat) const
{
  float ar, ag, ab, dr, dg , db, sr, sg, sb, shine, opac;

  // ambient coefficients
  _parse_float(sstr, ar);
  _parse_float(sstr, ag);
  _parse_float(sstr, ab);

  // diffuse coefficients
  _parse_float(sstr, dr);
  _parse_float(sstr, dg);
  _parse_float(sstr, db);

  // specular coefficients
  _parse_float(sstr, sr);
  _parse_float(sstr, sg);
  _parse_float(sstr, sb);

  // shininess
  _parse_float(sstr, shine);

  // opacity
  if (_parse_float(sstr, opac)) {
    mat.ambient   = gpucast::gl::vec3f(ar, ag, ab);
    mat.diffuse   = gpucast::gl::vec3f(dr, dg, db);
    mat.specular  = gpucast::gl::vec3f(sr, sg, sb);
    mat.shininess = shine;
    mat.opacity   = opac;
	} else {
	  std::cerr << "application::read_material(): material definition incomplete. discarding.\n usage: material ar ab ag   dr dg db  sr sg sb  shininess   opacity";
	}
}


///////////////////////////////////////////////////////////////////////////////
bool
glwidget::_parse_float(std::istringstream& sstr, float& result) const
{
  if (sstr) {
    sstr >> result;
    return true;
  } else {
    return false;
  }
}

///////////////////////////////////////////////////////////////////////////////
void
glwidget::_parse_background(std::istringstream& sstr, gpucast::gl::vec3f& bg) const
{
  float r, g, b;
  sstr >> r >> g >> b;
  bg = gpucast::gl::vec3f(r, g, b);
}