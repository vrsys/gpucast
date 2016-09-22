###############################################################################
# set sources
###############################################################################
FILE(GLOB EXAMPLE_ATOMIC_COUNTER_SRC RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.cpp)

GET_FILENAME_COMPONENT(_EXE_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)
SET(_EXE_NAME example_${_EXE_NAME}.out)
PROJECT(${_EXE_NAME})

SET(EXECUTABLE_OUTPUT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

INCLUDE_DIRECTORIES( ${INCLUDE_PATHS} 
                     ${CMAKE_CURRENT_SOURCE_DIR}/include 
                     ${CMAKE_SOURCE_DIR}/gpucast_math/include 
                     ${CMAKE_SOURCE_DIR}/gpucast_gl/include
                     ${CMAKE_SOURCE_DIR}/gpucast_glut/include
                     ${CMAKE_SOURCE_DIR}/gpucast_core/include
                     ${GLFW_INCLUDE_DIR}
                     ${GLEW_INCLUDE_DIR}
)

SET(LIBRARY_DIRS ${LIB_PATHS} 
                 ${GLEW_LIBRARY_DIRS} 
                 ${QHULL_LIBRARY_DIRS} 
                 ${FREEIMAGE_LIBRARY_DIRS}
                 ${FREEGLUT_LIBRARY_DIRS}
)

LINK_DIRECTORIES (${LIBRARY_DIRS})

add_definitions(-D FREEGLUT_LIB_PRAGMAS=0)

ADD_EXECUTABLE( ${_EXE_NAME}
    ${EXAMPLE_ATOMIC_COUNTER_SRC}
)

SET_TARGET_PROPERTIES( ${_EXE_NAME} PROPERTIES COMPILE_FLAGS ${BUILD_FLAGS})

###############################################################################
# dependencies
###############################################################################
ADD_DEPENDENCIES(${_EXE_NAME} gpucast_math gpucast_gl gpucast_glut gpucast_core)

IF (MSVC)
TARGET_LINK_LIBRARIES(${_EXE_NAME} 
                      gpucast_gl 
                      gpucast_glut
                      gpucast_core
		                  debug ${GLFW_LIBRARY_DEBUG} optimized ${GLFW_LIBRARY_RELEASE}
                      debug ${FREEIMAGE_LIBRARY_DEBUG} optimized ${FREEIMAGE_LIBRARY}
                      debug ${FREEIMAGE_PLUS_LIBRARY_DEBUG} optimized ${FREEIMAGE_PLUS_LIBRARY}
                      )
ELSE (MSVC)
TARGET_LINK_LIBRARIES(${_EXE_NAME} 
		                  gpucast_gl 
                      gpucast_glut
	                    gpucast_core
		                  ${GLFW_LIBRARY}
		                  ${FREEIMAGE_LIBRARY}
		                  ${FREEIMAGE_PLUS_LIBRARY}
		                  ${GLEW_LIBRARY}
                      boost_filesystem
                      boost_regex
                      GL GLU )
ENDIF (MSVC)

###############################################################################
# copy runtime libraries as a post-build process
###############################################################################
copy_external_runtime_libraries()
apply_debug_working_directory()