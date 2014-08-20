##############################################################################
# search paths
##############################################################################
SET(GLFW_INCLUDE_SEARCH_DIRS
  ${GLOBAL_EXT_DIR}/include/GLFW
  ${GLFW_INCLUDE_SEARCH_DIR}
  /opt/glfw3/current/include
  /usr/include
)

SET(GLFW_LIBRARY_SEARCH_DIRS
  ${GLOBAL_EXT_DIR}/lib
  ${GLFW_LIBRARY_SEARCH_DIR}
  /opt/glfw3/current/lib
  /usr/lib
  /usr/lib/x86_64-linux-gnu
)

##############################################################################
# search
##############################################################################
message(STATUS "-- checking for GLFW")

find_path(GLFW_INCLUDE_DIR NAMES GLFW/glfw3.h PATHS ${GLFW_INCLUDE_SEARCH_DIRS})

IF (MSVC)
	find_library(GLFW_LIBRARY_RELEASE NAMES glfw3.lib PATHS ${QHULL_LIBRARY_SEARCH_DIRS} PATH_SUFFIXES release)
	find_library(GLFW_LIBRARY_DEBUG NAMES glfw3.lib glfw3d.lib PATHS ${QHULL_LIBRARY_SEARCH_DIRS} PATH_SUFFIXES debug)
ELSEIF (UNIX)
	find_library(GLFW_LIBRARY NAMES libglfw3.a PATHS ${QHULL_LIBRARY_SEARCH_DIRS})
ENDIF (MSVC)
