
# Generate CMake code and put the result in res.
# For instance:
#  set(FOO bar)
#  set(SPAM eggs)
#
#  _qi_gen_code_from_vars(res FOO SPAM)
# Causes res to contain:
#
#  set(FOO "bar")
#  mark_as_advanced(FOO)
#  set(SPAM "eggs")
#  mark_as_advanced(SPAM)

include(CMakeParseArguments)
set(QI_SDK_INCLUDE "include")

function(_qi_gen_code_from_vars res)
  set(_res "")
  foreach(_arg ${ARGN})
    set(_name ${_arg})
    set(_value "${${_arg}}")
    set(_res "${_res}
set(${_name} \"${_value}\" CACHE STRING \"\" FORCE)
mark_as_advanced(${_name})
")
  endforeach()
  set(${res} ${_res} PARENT_SCOPE)
endfunction()


function(_qi_gen_header_code_redist res)
  # The generated file will be installed in:
  # root_dir/share/cmake/${_target}/${_target}-config.cmake,
  # so we can find root_dir from the location of the generated file...
  set(_header
"# This is an autogenerated file. Do not edit

get_filename_component(_cur_dir \${CMAKE_CURRENT_LIST_FILE} PATH)
set(_root_dir \"\${_cur_dir}/../../../\")
get_filename_component(ROOT_DIR \${_root_dir} ABSOLUTE)

"
  )
  set(_res "${_header}")
  set(${res} ${_res} PARENT_SCOPE)
endfunction()


function(_qi_gen_find_lib_code_redist res target)
  string(TOUPPER ${target} _U_target)
  if("${target}_SUBFOLDER" STREQUAL "")
    set(_res
"
find_library(${_U_target}_DEBUG_LIBRARY ${target}_d)
find_library(${_U_target}_LIBRARY       ${target})
")
  else()
    set(_res
"
find_library(${_U_target}_DEBUG_LIBRARY ${target}_d PATH_SUFFIXES ${${target}_SUBFOLDER})
find_library(${_U_target}_LIBRARY       ${target}   PATH_SUFFIXES ${${target}_SUBFOLDER})
")
  endif()
  set(_res
"
${_res}

if (${_U_target}_DEBUG_LIBRARY)
  set(${_U_target}_LIBRARIES optimized;\${${_U_target}_LIBRARY};debug;\${${_U_target}_DEBUG_LIBRARY})
else()
  set(${_U_target}_LIBRARIES \${${_U_target}_LIBRARY})
endif()
set(${_U_target}_LIBRARIES \"\${${_U_target}_LIBRARIES}\" CACHE STRING \"\" FORCE)
mark_as_advanced(${_U_target}_LIBRARIES)
")
  set(${res} ${_res} PARENT_SCOPE)
endfunction()


function(_qi_gen_find_lib_code_sdk res target)
  string(TOUPPER ${target} _U_target)
  get_target_property(_target_type  ${target}   TYPE)

  if(WIN32)
    if(MSVC)
      # Trust ARCHIVE_OUTPUT_DIRECTORY, and handle the _d:
      get_target_property(_lib_dir_debug   ${target}  ARCHIVE_OUTPUT_DIRECTORY_DEBUG)
      get_target_property(_lib_dir_release ${target}  ARCHIVE_OUTPUT_DIRECTORY_RELEASE)
      set(_lib_name_debug   "${target}_d.lib")
      set(_lib_name_release "${target}.lib")
      set(_lib_debug "${_lib_dir_debug}/${_lib_name_debug}")
      set(_lib_release "${_lib_dir_release}/${_lib_name_release}")
      set(${_U_target}_LIBRARIES "debug;${_lib_debug};optimized;${_lib_release}")
    else()
      # Mingw: lib is .a when building a static library, and
      # .dll.a when building a shared library
      get_target_property(_lib_dir ${target} "ARCHIVE_OUTPUT_DIRECTORY")
      if("${_target_type}" STREQUAL SHARED_LIBRARY)
        set(_lib_name    "lib${target}.dll.a")
      else()
        set(_lib_name    "lib${target}.a")
      endif()
      set(${_U_target}_LIBRARIES "general;${_lib_dir}/${_lib_name}")
    endif()
  else()
    # Not win32:
    if("${_target_type}" STREQUAL "SHARED_LIBRARY")
      get_target_property(_lib_dir  ${target}  "LIBRARY_OUTPUT_DIRECTORY")
      if(APPLE)
        set(_lib_name "lib${target}.dylib")
      else()
        set(_lib_name "lib${target}.so")
      endif()
    else()
      get_target_property(_lib_dir  ${target}  "ARCHIVE_OUTPUT_DIRECTORY")
      set(_lib_name "lib${target}.a")
    endif()
    set(${_U_target}_LIBRARIES "general;${_lib_dir}/${_lib_name}")
  endif()

  _qi_gen_code_from_vars(_res ${_U_target}_LIBRARIES)
  set(${res} ${_res} PARENT_SCOPE)
endfunction()


# Here we have a list of relative paths, we want
# to write a variable with these paths preprend with
# ${ROOT_DIR}/include, the root include dir of the
# installed SDK.
function(_qi_gen_inc_dir_code_redist res target)
  string(TOUPPER ${target} _U_target)

  set(_suffixes)
  foreach(_suffix ${${_U_target}_PATH_SUFFIXES})
    list(APPEND _suffixes "\${ROOT_DIR}/include/${_suffix}")
  endforeach()

  set(_res "
set(${_U_target}_INCLUDE_DIRS \"\${ROOT_DIR}/include;${_suffixes}\" CACHE STRING \"\" FORCE)
mark_as_advanced(${_U_target}_INCLUDE_DIRS)
  "
  )

  set(${res} ${_res} PARENT_SCOPE)
endfunction()


# Here we have a list of relative paths, we want to write
# the absolute paths in CMAKE_BINARY_DIR/sdk/cmake/target-config.cmake
function(_qi_gen_inc_dir_code_sdk res target)
  string(TOUPPER ${target} _U_target)
  get_directory_property(_inc_dirs INCLUDE_DIRECTORIES)
  list(APPEND ${_U_target}_INCLUDE_DIRS ${_inc_dirs})

  _qi_gen_code_from_vars(_res ${_U_target}_INCLUDE_DIRS)

  set(${res} ${_res} PARENT_SCOPE)
endfunction()



# Generate CMake code to be put in a
# ${target}-config.cmake, ready to be installed
function(_qi_gen_code_lib_redist res target)
  string(TOUPPER ${target} _U_target)
  set(_res "")

  # Header:
  _qi_gen_header_code_redist(_header ${target})
  set(_res ${_header})

  ## INCLUDE_DIRS:
  _qi_gen_inc_dir_code_redist(_inc ${target})
  set(_res "${_res} ${_inc}")

  # DEPENDS, DEFINITIONS:
  _qi_gen_code_from_vars(_defs
    ${_U_target}_DEPENDS
    ${_U_target}_DEFINITIONS)
  set(_res "${_res} ${_defs}")

  # Find libs:
  _qi_gen_find_lib_code_redist(_find_libs ${target})
  set(_res "${_res} ${_find_libs}")

  # FindPackageHandleStandardArgs:
  set(_call_fphsa
"
include(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(${_U_target} DEFAULT_MSG
  ${_U_target}_LIBRARIES
  ${_U_target}_INCLUDE_DIRS
)
# Right after find_package_handle_standard_args, ${prefix}_FOUND is
# set correctly.
# For instance, if foo/bar.h is not foud, FOO_FOUND is FALSE.
# But, right after this, since foo-config.cmake HAS been found, CMake
# re-set FOO_FOUND to TRUE.
# So we set ${prefix}_PACKAGE_FOUND in cache...
set(${_U_target}_PACKAGE_FOUND \${${_U_target}_FOUND} CACHE INTERNAL \"\" FORCE)
")

  set(_res "${_res} ${_call_fphsa}")

  set(${res} ${_res} PARENT_SCOPE)
endfunction()

# Generate CMake code to be put in a
# ${target}-config.cmake, ready to be installed
function(_qi_gen_code_header_only_lib_redist res target)
  string(TOUPPER ${target} _U_target)
  set(_res "")

  # Header:
  _qi_gen_header_code_redist(_header ${target})
  set(_res ${_header})

  ## INCLUDE_DIRS:
  _qi_gen_inc_dir_code_redist(_inc ${target})
  set(_res "${_res} ${_inc}")

  # DEPENDS, DEFINITIONS:
  _qi_gen_code_from_vars(_defs
    ${_U_target}_DEPENDS
    ${_U_target}_DEFINITIONS)
  set(_res "${_res} ${_defs}")

  # FindPackageHandleStandardArgs:
  set(_call_fphsa
"
include(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(${_U_target} DEFAULT_MSG
  ${_U_target}_INCLUDE_DIRS
)
# Right after find_package_handle_standard_args, ${prefix}_FOUND is
# set correctly.
# For instance, if foo/bar.h is not foud, FOO_FOUND is FALSE.
# But, right after this, since foo-config.cmake HAS been found, CMake
# re-set FOO_FOUND to TRUE.
# So we set ${prefix}_PACKAGE_FOUND in cache...
set(${_U_target}_PACKAGE_FOUND \${${_U_target}_FOUND} CACHE INTERNAL \"\" FORCE)
")

  set(_res "${_res} ${_call_fphsa}")

  set(${res} ${_res} PARENT_SCOPE)
endfunction()



# Generate CMake code to be put in a
# ${target}-config.cmake, ready to be included
# by other projects from the build dir
function(_qi_gen_code_lib_sdk res target)
  string(TOUPPER ${target} _U_target)
  set(_res
  "# Autogenerated file.
# Do not edit.
# Do not change location.
")
  _qi_gen_inc_dir_code_sdk(_inc ${target})
  set(_res "${_res} ${_inc}")

  _qi_gen_find_lib_code_sdk(_lib ${target})
  set(_res "${_res} ${_lib}")

  # needed for local config.cmake only, it will be used by qi_use_lib,
  # to add local dependencies between target (in the same project)
  set(${_U_target}_TARGET    "${target}")
  _qi_gen_code_from_vars(_defs
    ${_U_target}_TARGET
    ${_U_target}_DEPENDS
    ${_U_target}_DEFINITIONS
  )
  set(_res "${_res} ${_defs}")

  set(_res "${_res}
 set(${_U_target}_PACKAGE_FOUND TRUE CACHE INTERNAL \"\" FORCE)
  ")
  set(${res} ${_res} PARENT_SCOPE)
endfunction()

# Generate CMake code to be put in a
# ${target}-config.cmake, ready to be included
# by other projects from the build dir
function(_qi_gen_code_header_only_lib_sdk res target)
  string(TOUPPER ${target} _U_target)
  set(_res
  "# Autogenerated file.
# Do not edit.
# Do not change location.
")
  _qi_gen_inc_dir_code_sdk(_inc ${target})
  set(_res "${_res} ${_inc}")

  # _qi_gen_find_lib_code_sdk(_lib ${target})
  # set(_res "${_res} ${_lib}")

  # needed for local config.cmake only, it will be used by qi_use_lib,
  # to add local dependencies between target (in the same project)
  #set(${_U_target}_TARGET    "${target}")
    #${_U_target}_TARGET
  _qi_gen_code_from_vars(_defs
    ${_U_target}_DEPENDS
    ${_U_target}_DEFINITIONS
  )
  set(_res "${_res} ${_defs}")

  set(_res "${_res}
 set(${_U_target}_PACKAGE_FOUND TRUE CACHE INTERNAL \"\" FORCE)
  ")
  set(${res} ${_res} PARENT_SCOPE)
endfunction()



# Usage:
# _qi_set_vars target
#
# accepted group of flags:
#  DEPENDS
#  DEFINITIONS
#  INCLUDE_DIRS
#  PATH_SUFFIXES
# (those will be guessed if not given:
# target_DEPENDS <- filled by qi_use_lib
# target_INCLUDE_DIRS <- using get_direcotry_properties()
# target_DEFINITIONS <- definitions are never guessed,
# use stage_lib(foo DEFINITIONS "-DSPAM=EGGS") if you need this.
function(_qi_set_vars target)
  string(TOUPPER ${target} _U_target)
  cmake_parse_arguments(ARG ""
    ""
    "DEPENDS;DEFINITIONS;INCLUDE_DIRS;PATH_SUFFIXES"
    ${ARGN})
  if(ARG_DEPENDS)
    set(${_U_target}_DEPENDS ${ARG_DEPENDS} PARENT_SCOPE)
  endif()

  if(ARG_DEFINITIONS)
    string(REPLACE "\"" "\\\""  _defs ${ARG_DEFINITIONS})
    set(${_U_target}_DEFINITIONS ${_defs} PARENT_SCOPE)
  endif()

  if(ARG_INCLUDE_DIRS)
    set(${_U_target}_INCLUDE_DIRS ${ARG_INCLUDE_DIRS} PARENT_SCOPE)
  else()
    # ARG_INCLUDE_DIRS defaults to ${CMAKE_CURRENT_SOURCE_DIR}
    set(${_U_target}_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR} PARENT_SCOPE)
  endif()

  if(ARG_PATH_SUFFIXES)
    set(${_U_target}_PATH_SUFFIXES ${ARG_PATH_SUFFIXES} PARENT_SCOPE)
  else()
    set(${_U_target}_PATH_SUFFIXES "" PARENT_SCOPE)
  endif()


endfunction()

function(_qi_internal_append_deprecated OUT_RESULT target)
  cmake_parse_arguments(ARG "INTERNAL" "" "DEPRECATED" ${ARGN})
  set(_result)
  set(_result "${_result}\nmessage(STATUS \"\")\n")
  if (ARG_INTERNAL)
    set(_result "${_result}\nmessage(STATUS \"## INTERNAL: ${CMAKE_CURRENT_LIST_FILE}: ${target} is internal\")\n")
  else()
    set(_result "${_result}\nmessage(STATUS \"## DEPRECATED: ${CMAKE_CURRENT_LIST_FILE}: ${target} is deprecated: ${ARG_DEPRECATED}\")\n")
  endif()
  set(_result "${_result}\nmessage(STATUS \"\")\n")
  set("${OUT_RESULT}" "${${OUT_RESULT}}${_result}" PARENT_SCOPE)
endfunction()

function(_qi_internal_stage_lib target)
  cmake_parse_arguments(ARG "INTERNAL" "STAGED_NAME" "DEPRECATED;INCLUDE_DIRS;DEFINITIONS;PATH_SUFFIXES;DEPENDS" ${ARGN})
  string(TOUPPER ${target} _U_target)
  string(TOLOWER ${target} _l_target)
  set(_staged_name ${ARG_STAGED_NAME})
  set(_new_args)
  foreach(_arg INCLUDE_DIRS DEFINITIONS PATH_SUFFIXES DEPENDS)
    if (DEFINED ARG_${_arg})
      list(APPEND _new_args "${_arg}" "${ARG_${_arg}}")
    endif()
  endforeach()

  _qi_set_vars(${target} ${_new_args})

  #todo: enable me...
  #if (NOT ARG_INTERNAL OR QI_INSTALL_INTERNAL)
    _qi_gen_code_lib_redist(_redist ${target})
    set(_redist_file "${CMAKE_BINARY_DIR}/${QI_SDK_CMAKE_MODULES}/sdk/${_l_target}-config.cmake")
    if (ARG_DEPRECATED)
      _qi_internal_append_deprecated(_redist ${target} DEPRECATED ${ARG_DEPRECATED})
    endif()
    if (ARG_INTERNAL)
      _qi_internal_append_deprecated(_redist ${target} INTERNAL)
    endif()
    file(WRITE "${_redist_file}" "${_redist}")
    qi_install_cmake(${_redist_file} SUBFOLDER ${target})
  #endif()

  _qi_gen_code_lib_sdk(_sdk ${target})
  set(_sdk_file "${QI_SDK_DIR}/${QI_SDK_CMAKE_MODULES}/${_l_target}-config.cmake")
  if (ARG_DEPRECATED)
    _qi_internal_append_deprecated(_sdk ${target} DEPRECATED ${ARG_DEPRECATED})
  endif()
  file(WRITE "${_sdk_file}" "${_sdk}")

  # OK, this one is tricky.
  # with qibuild, when you have a target named "foo", you always prefix
  # the variables concerning the foo target with the upper-case name
  # of the target (FOO_INCLUDE_DIRS, FOO_DEFINITIONS, FOO_DEPENDS....)

  # previously, when using toc/t001chain, you could stage a library
  # with whatever named you wanted. For instance, you could use:
  # stage_lib(foo LIBFOO)

  # In order to preserve backward compatibility, (for instance use_lib(bar LIBFOO)
  # MUST continue to work), when we stumble upon this kind of call in compat/compat.cmake,
  # we create two different modules.

  # one is still called foo-config.cmake, the other one is a copy of foo-config.cmake,
  # named libfoo-config.cmake, where every occurrence of "FOO" is replaced by
  # LIBFOO.
  # This way, only the *names* of the values changed, but not their value, so
  # LIBFOO_DEPENDS is the same as FOO_DEPENDS

  # TODO: this little final hack is not very safe. Maybe a better way to do it will
  # be to generate a file looking like

  #   message(STAUS "Usage of
  #       use_lib(... LIBFOO)
  #   is deprecated, please use
  #       qi_use_lib(.. foo)
  #   find_package(foo)
  #   ")
  #
  #   set(LIBFOO_DEPENDS ${FOO_DEPENDS}
  #   set(LIBFOO_INLUDE_DIRS ${FOO_INCLUDE_DIRS}
  #
  #

  if(_staged_name)
    set(_warning_message
"
message(WARNING \${CMAKE_CURRENT_LIST_FILE}\"
  Usage of :
    use_lib(... ${_staged_name})
  is deprecated
  Use:
    qi_use_lib(... ${target})
    or
    use_lib(... ${_U_target})
   instead
\")
"  )

    qi_verbose("Staging ${_staged_name} instead of ${target}!")
    string(TOUPPER ${target} _U_target)
    string(TOLOWER ${_staged_name} _other_name)
    string(TOUPPER ${_staged_name} _U_staged_name)

    #ARG_INTERNAL not handled here, we dont really care, user already have a deprecated message..
    #todo: enable
    #if (NOT ARG_INTERNAL OR QI_INSTALL_INTERNAL)
      string(REPLACE ${_U_target} ${_U_staged_name} _other_redist "${_redist}")
      set(_other_redist_file "${CMAKE_BINARY_DIR}/${QI_SDK_CMAKE_MODULES}/sdk/${_other_name}-config.cmake")
      file(WRITE  "${_other_redist_file}" "${_other_redist}")
      file(APPEND "${_other_redist_file}" ${_warning_message})
      qi_install_cmake(${_other_redist_file} SUBFOLDER ${_other_name})
    #endif()

    string(REPLACE ${_U_target} ${_U_staged_name} _other_sdk "${_sdk}")
    set(_other_sdk_file "${QI_SDK_DIR}/${QI_SDK_CMAKE_MODULES}/${_other_name}-config.cmake")
    file(WRITE  "${_other_sdk_file}" "${_other_sdk}")
    file(APPEND "${_other_sdk_file}" ${_warning_message})

  endif()

endfunction()




function(_qi_internal_stage_header_only_lib target)
  cmake_parse_arguments(ARG "INTERNAL" "" "DEPRECATED;INCLUDE_DIRS;DEFINITIONS;PATH_SUFFIXES;DEPENDS" ${ARGN})
  string(TOUPPER ${target} _U_target)
  string(TOLOWER ${target} _l_target)
  #set(_staged_name ${ARG_STAGED_NAME})
  set(_new_args)
  foreach(_arg INCLUDE_DIRS DEFINITIONS PATH_SUFFIXES DEPENDS)
    if (DEFINED ARG_${_arg})
      list(APPEND _new_args "${_arg}" "${ARG_${_arg}}")
    endif()
  endforeach()

  _qi_set_vars(${target} ${_new_args})

  #todo: enable me...
  #if (NOT ARG_INTERNAL OR QI_INSTALL_INTERNAL)
    _qi_gen_code_header_only_lib_redist(_redist ${target})
    set(_redist_file "${CMAKE_BINARY_DIR}/${QI_SDK_CMAKE_MODULES}/sdk/${_l_target}-config.cmake")
    if (ARG_DEPRECATED)
      _qi_internal_append_deprecated(_redist ${target} DEPRECATED ${ARG_DEPRECATED})
    endif()
    if (ARG_INTERNAL)
      _qi_internal_append_deprecated(_redist ${target} INTERNAL)
    endif()
    file(WRITE "${_redist_file}" "${_redist}")
    qi_install_cmake(${_redist_file} SUBFOLDER ${target})
  #endif()

  _qi_gen_code_header_only_lib_sdk(_sdk ${target})
  set(_sdk_file "${QI_SDK_DIR}/${QI_SDK_CMAKE_MODULES}/${_l_target}-config.cmake")
  if (ARG_DEPRECATED)
    _qi_internal_append_deprecated(_sdk ${target} DEPRECATED ${ARG_DEPRECATED})
  endif()
  file(WRITE "${_sdk_file}" "${_sdk}")

endfunction()
