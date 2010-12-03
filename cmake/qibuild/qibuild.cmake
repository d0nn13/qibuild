##
## Author(s):
##  - Cedric GESTES <gestes@aldebaran-robotics.com>
##
## Copyright (C) 2010 Aldebaran Robotics
##

#get the current directory of the file
get_filename_component(_ROOT_DIR ${CMAKE_CURRENT_LIST_FILE} PATH)
list(APPEND CMAKE_PREFIX_PATH ${_ROOT_DIR}/modules/)
#TODO: change the path
list(APPEND CMAKE_PREFIX_PATH ${CMAKE_BINARY_DIR}/sdk/lib/cmake/modules)


include("qibuild/log")
include("qibuild/set")
include("qibuild/expect")
include("qibuild/subdirectory")
include("qibuild/internal/layout")
include("qibuild/internal/check")
include("qibuild/internal/install")
include("qibuild/internal/glob")
include("qibuild/internal/stage")

if (NOT QI_SDK_DIR)
  qi_set_global(QI_SDK_DIR "${CMAKE_BINARY_DIR}/sdk/")
  qi_info("QI_SDK_DIR: ${QI_SDK_DIR}")
endif (NOT QI_SDK_DIR)

#force buildtype to be Upper case
if (DEFINED CMAKE_BUILD_TYPE)
  string(TOUPPER "${CMAKE_BUILD_TYPE}" "_BUILD_TYPE")
  qi_set_global(CMAKE_BUILD_TYPE "${_BUILD_TYPE}")
endif()

#ensure CMAKE_BUILD_TYPE is either Debug or Release
if (CMAKE_BUILD_TYPE STREQUAL "")
  qi_set_global(CMAKE_BUILD_TYPE "RELEASE")
endif (CMAKE_BUILD_TYPE STREQUAL "")

include("qibuild/find")
include("qibuild/uselib")
include("qibuild/launcher")
include("qibuild/tests")
include("qibuild/install")
include("qibuild/target")
include("qibuild/submodule")
include("qibuild/stage")
include("qibuild/sdk")
include("qibuild/doc")


_qi_create_sdk()
#qi_include_sdk(${QI_SDK_DIR})
set(CMAKE_PREFIX_PATH ${QI_SDK_DIR} ${CMAKE_PREFIX_PATH})
#qi_create_root()
