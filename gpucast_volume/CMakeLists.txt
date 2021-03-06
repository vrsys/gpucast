###############################################################################
# determine source and header files
###############################################################################
FILE ( GLOB GPUCAST_VOLUME_INC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} include/gpucast/volume/*.hpp )
FILE ( GLOB GPUCAST_VOLUME_IMPORT_INC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} include/gpucast/volume/import/*.hpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_INC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} include/gpucast/volume/isosurface/*.hpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_FRAGMENT_INC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} include/gpucast/volume/isosurface/fragment/*.hpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_GRID_INC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} include/gpucast/volume/isosurface/grid/*.hpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_SPLAT_INC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} include/gpucast/volume/isosurface/splat/*.hpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_OCTREE_INC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} include/gpucast/volume/isosurface/octree/*.hpp )

FILE ( GLOB GPUCAST_VOLUME_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} src/*.cpp )
FILE ( GLOB GPUCAST_VOLUME_IMPORT_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} src/import/*.cpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} src/isosurface/*.cpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_FRAGMENT_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} src/isosurface/fragment/*.cpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_GRID_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} src/isosurface/grid/*.cpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_SPLAT_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} src/isosurface/splat/*.cpp )
FILE ( GLOB GPUCAST_VOLUME_ISOSURFACE_OCTREE_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} src/isosurface/octree/*.cpp )

FILE ( GLOB_RECURSE GPUCAST_VOLUME_CUDA_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} kernel/*.cu )
FILE ( GLOB_RECURSE GPUCAST_VOLUME_CUDA_INC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} kernel/*.h )

SOURCE_GROUP("Source Files" FILES                       ${GPUCAST_VOLUME_INC})
SOURCE_GROUP("Source Files\\import" FILES               ${GPUCAST_VOLUME_IMPORT_INC})
SOURCE_GROUP("Source Files\\isosurface" FILES           ${GPUCAST_VOLUME_ISOSURFACE_INC})
SOURCE_GROUP("Source Files\\isosurface\\fragment" FILES ${GPUCAST_VOLUME_ISOSURFACE_FRAGMENT_INC})
SOURCE_GROUP("Source Files\\isosurface\\grid"     FILES ${GPUCAST_VOLUME_ISOSURFACE_GRID_INC})
SOURCE_GROUP("Source Files\\isosurface\\splat"    FILES ${GPUCAST_VOLUME_ISOSURFACE_SPLAT_INC})
SOURCE_GROUP("Source Files\\isosurface\\octree"   FILES ${GPUCAST_VOLUME_ISOSURFACE_OCTREE_INC})

SOURCE_GROUP("Source Files" FILES                       ${GPUCAST_VOLUME_SRC})
SOURCE_GROUP("Source Files\\import" FILES               ${GPUCAST_VOLUME_IMPORT_SRC})
SOURCE_GROUP("Source Files\\isosurface" FILES           ${GPUCAST_VOLUME_ISOSURFACE_SRC})
SOURCE_GROUP("Source Files\\isosurface\\fragment" FILES ${GPUCAST_VOLUME_ISOSURFACE_FRAGMENT_SRC})
SOURCE_GROUP("Source Files\\isosurface\\grid"     FILES ${GPUCAST_VOLUME_ISOSURFACE_GRID_SRC})
SOURCE_GROUP("Source Files\\isosurface\\splat"    FILES ${GPUCAST_VOLUME_ISOSURFACE_SPLAT_SRC})
SOURCE_GROUP("Source Files\\isosurface\\octree"   FILES ${GPUCAST_VOLUME_ISOSURFACE_OCTREE_SRC})

SOURCE_GROUP("Source Files\\CUDA"   FILES ${GPUCAST_VOLUME_CUDA_SRC})
SOURCE_GROUP("Source Files\\CUDA"   FILES ${GPUCAST_VOLUME_CUDA_INC})

FILE ( GLOB GPUCAST_GL_GLSL_FRAGLIST RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ../resources/glsl/volumefraglistraycasting/* )
FILE ( GLOB GPUCAST_GL_GLSL_OCTREE RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ../resources/glsl/octree/* )
FILE ( GLOB GPUCAST_GL_GLSL_ISOSURFACE RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ../resources/glsl/volumefraglistisosurface/* )
FILE ( GLOB GPUCAST_GL_GLSL_FRAGEGENERATOR RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ../resources/glsl/volumefragmentgenerator/* )
FILE ( GLOB GPUCAST_GL_GLSL_VOLUMESAMPLER RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ../resources/glsl/volumesampler/* )
FILE ( GLOB GPUCAST_GL_GLSL_VOLUMETESSELATOR RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ../resources/glsl/volumetesselator/* )
FILE ( GLOB GPUCAST_GL_GLSL_VOLUMEBOUNDS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ../resources/glsl/volumetransparentbounds/* )

SOURCE_GROUP("Resources\\volumefraglistraycasting" FILES ${GPUCAST_GL_GLSL_FRAGLIST})
SOURCE_GROUP("Resources\\octree" FILES ${GPUCAST_GL_GLSL_OCTREE})
SOURCE_GROUP("Resources\\volumefraglistisosurface" FILES ${GPUCAST_GL_GLSL_ISOSURFACE})
SOURCE_GROUP("Resources\\volumefragmentgenerator" FILES ${GPUCAST_GL_GLSL_FRAGEGENERATOR})
SOURCE_GROUP("Resources\\volumesampler" FILES ${GPUCAST_GL_GLSL_VOLUMESAMPLER})
SOURCE_GROUP("Resources\\volumetesselator" FILES ${GPUCAST_GL_GLSL_VOLUMETESSELATOR})
SOURCE_GROUP("Resources\\volumetransparentbounds" FILES ${GPUCAST_GL_GLSL_VOLUMEBOUNDS})


LINK_DIRECTORIES(${LIB_PATHS} ${BOOST_LIBRARY_DIRS} ${QHULL_LIBRARY_DIRS} ${FREEIMAGE_LIBRARY_DIRS})

SET(CUDA_NVCC_FLAGS ${CUDA_NVCC_FLAGS} -D_FORCE_INLINES -gencode arch=compute_61,code=sm_61)
SET(CUDA_NVCC_FLAGS_DEBUG ${CUDA_NVCC_FLAGS} )
SET(CUDA_NVCC_FLAGS_RELEASE ${CUDA_NVCC_FLAGS} )

CUDA_INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR}/include
                         ${CMAKE_CURRENT_SOURCE_DIR}/kernel
                         ${CMAKE_SOURCE_DIR}/gpucast_gl/include
                         ${CMAKE_SOURCE_DIR}/gpucast_math/include
                         ${CMAKE_SOURCE_DIR}/gpucast_core/include
                         ${CMAKE_SOURCE_DIR}/externals/include/glew
                         ${GLEW_INCLUDE_DIR})

SET(GPUCAST_VOLUME_PASSTHROUGH_SRC kernel/external_passthrough.cu)
SET(CUDA_VERBOSE_BUILD ON)

SET(CUDA_PASSTHROUGH_KERNEL_SRC kernel/external_passthrough.cu)
SET(CUDA_RAYCAST_FRAGLISTS_KERNEL_SRC kernel/raycast_fragmentlists.cu)
SET(CUDA_RAYCAST_GRID_KERNEL_SRC kernel/raycast_grid.cu)
SET(CUDA_RAYCAST_OCTREE_KERNEL_SRC kernel/raycast_octree.cu)
SET(CUDA_VOLUME_SPLAT_KERNEL_SRC kernel/splat_volume_samples.cu)

CUDA_ADD_LIBRARY( gpucast_volume SHARED
             ${GPUCAST_VOLUME_SRC}
             ${GPUCAST_VOLUME_IMPORT_SRC}
             ${GPUCAST_VOLUME_ISOSURFACE_SRC}
             ${GPUCAST_VOLUME_ISOSURFACE_FRAGMENT_SRC}
             ${GPUCAST_VOLUME_ISOSURFACE_GRID_SRC}
             ${GPUCAST_VOLUME_ISOSURFACE_SPLAT_SRC}
             ${GPUCAST_VOLUME_ISOSURFACE_OCTREE_SRC}
             ${GPUCAST_VOLUME_INC}
             ${GPUCAST_VOLUME_IMPORT_INC}
             ${GPUCAST_VOLUME_ISOSURFACE_INC}
             ${GPUCAST_VOLUME_ISOSURFACE_FRAGMENT_INC}
             ${GPUCAST_VOLUME_ISOSURFACE_GRID_INC}
             ${GPUCAST_VOLUME_ISOSURFACE_SPLAT_INC}
             ${GPUCAST_VOLUME_ISOSURFACE_OCTREE_INC}
             ${CUDA_PASSTHROUGH_KERNEL_SRC}
             ${CUDA_RAYCAST_FRAGLISTS_KERNEL_SRC}
             ${CUDA_RAYCAST_GRID_KERNEL_SRC}
             ${CUDA_RAYCAST_OCTREE_KERNEL_SRC}
             ${CUDA_VOLUME_SPLAT_KERNEL_SRC}       
             ${GPUCAST_GL_GLSL_FRAGLIST}
             ${GPUCAST_GL_GLSL_OCTREE}
             ${GPUCAST_GL_GLSL_ISOSURFACE}
             ${GPUCAST_GL_GLSL_FRAGEGENERATOR}
             ${GPUCAST_GL_GLSL_VOLUMESAMPLER}
             ${GPUCAST_GL_GLSL_VOLUMETESSELATOR}
             ${GPUCAST_GL_GLSL_VOLUMEBOUNDS}
)

INCLUDE_DIRECTORIES( ${INCLUDE_PATHS} 
                     ${GLEW_INCLUDE_DIR}
                     ${QHULL_INCLUDE_DIR} 
                     ${CUDA_INCLUDE_DIRS}
                     ../gpucast_core/include
                     ../gpucast_gl/include
                     ../gpucast_math/include
                     include
                     kernel )

###############################################################################
# set preprocessor configuration
###############################################################################
SET (GPUCAST_VOLUME_BUILD_FLAGS ${BUILD_FLAGS})

IF (MSVC)
  SET(GPUCAST_VOLUME_BUILD_FLAGS "${GPUCAST_VOLUME_BUILD_FLAGS} -D GPUCAST_VOLUME_EXPORT")
ENDIF (MSVC)

SET_TARGET_PROPERTIES( gpucast_volume PROPERTIES COMPILE_FLAGS ${GPUCAST_VOLUME_BUILD_FLAGS})

###############################################################################
# dependencies
###############################################################################
ADD_DEPENDENCIES(gpucast_volume gpucast_math gpucast_core gpucast_gl)

IF (MSVC)
  TARGET_LINK_LIBRARIES( gpucast_volume 
                         gpucast_core 
                         gpucast_gl
                         ${CUDA_LIBRARIES}
  )
ELSEIF (UNIX)
  TARGET_LINK_LIBRARIES( gpucast_volume 
                         gpucast_core 
                         gpucast_gl
                         ${CUDA_LIBRARIES}
  )
ENDIF (MSVC)

###############################################################################
# install 
###############################################################################

IF (MSVC)
  install (TARGETS gpucast_volume
    CONFIGURATIONS Release
    RUNTIME DESTINATION bin/Release
    LIBRARY DESTINATION lib/Release
    ARCHIVE DESTINATION lib/Release
  )

  install (TARGETS gpucast_volume
    CONFIGURATIONS Debug
    RUNTIME DESTINATION bin/Debug
    LIBRARY DESTINATION lib/Debug
    ARCHIVE DESTINATION lib/Debug
  )
ELSEIF (UNIX)
  install (TARGETS gpucast_volume 
    RUNTIME DESTINATION lib
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
  )
ENDIF (MSVC)

# header files 
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/gpucast DESTINATION include/gpucast_volume FILES_MATCHING PATTERN "*.hpp")
