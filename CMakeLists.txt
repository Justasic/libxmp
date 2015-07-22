cmake_minimum_required(VERSION 2.8)

# Force external build
if(${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_BINARY_DIR} AND NOT WIN32)
	message(FATAL_ERROR "You can not use CMake to build from the root of it's source tree! Remove the CMakeCache.txt file from this directory, then create a separate directory (either below this directory or elsewhere), and then re-run CMake from there.")
endif(${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_BINARY_DIR} AND NOT WIN32)

# Project version
SET(PROJECT_MAJOR_VERSION 4)
SET(PROJECT_MINOR_VERSION 3)
SET(PROJECT_PATCH_LEVEL 9)

# Get the git revision location for the branch we're on
if(EXISTS "${CMAKE_SOURCE_DIR}/.git/HEAD")
	file(READ ${CMAKE_SOURCE_DIR}/.git/HEAD GIT_HEAD_LOC)
	string(LENGTH ${GIT_HEAD_LOC} HEAD_LEN)
	math(EXPR LEN "${HEAD_LEN} - 5")
	string(SUBSTRING ${GIT_HEAD_LOC} 5 ${LEN} GIT_HEAD)
	# Weird nastery to remove newlines which screw up the if statement below.
	set(GIT_SHA_PATH "${CMAKE_SOURCE_DIR}/.git/${GIT_HEAD}")
	string(REGEX REPLACE "(\r?\n)+$" "" GIT_SHA_PATH "${GIT_SHA_PATH}")
endif(EXISTS "${CMAKE_SOURCE_DIR}/.git/HEAD")

# Get the git revision we're on for the version string
if(EXISTS "${GIT_SHA_PATH}")
	file(READ "${GIT_SHA_PATH}" VERSION_STR)
	string(REGEX REPLACE "(\r?\n)+$" "" VERSION_STR "${VERSION_STR}")
	# Get the length of the string
	string(LENGTH ${VERSION_STR} VERSION_LEN)
	# Subtract 7 from the string's length
	math(EXPR VERSION_NUM_LEN "${VERSION_LEN} - ${VERSION_LEN} + 7")
	# Extract the value from the string
	string(SUBSTRING ${VERSION_STR} 0 ${VERSION_NUM_LEN} VERSION_GIT)
endif(EXISTS "${GIT_SHA_PATH}")

# Set our version strings
SET(VERSION_SIMPLE "${PROJECT_MAJOR_VERSION}.${PROJECT_MINOR_VERSION}.${PROJECT_PATCH_LEVEL}")
SET(VERSION_FULL "${PROJECT_MAJOR_VERSION}.${PROJECT_MINOR_VERSION}.${PROJECT_PATCH_LEVEL}-${VERSION_GIT}")

# Cmake module path (if exists)
#set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

file(GLOB SOURCE_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "src/*.c")
file(GLOB LOADER_SOURCES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "src/loaders/*.c")
list(APPEND SOURCE_FILES ${LOADER_FILES})
list(SORT SOURCE_FILES)

# Finally initialize our project
project(libxmp C)

# Build LIBXMP-LITE or nah?
option(LIBXMP_LITE "Build the lightweight embeddable library" OFF)
# Build static or shared? OFF = shared, ON = static
option(LIBXMP_STATIC "Build the library as static" OFF)

# Announce our project and project version.
message(STATUS "${PROJECT_NAME} version: ${VERSION_FULL}")

# Check for platform-specific things we need
include (CheckTypeSize)
include (CheckIncludeFile)
include (CheckLibraryExists)
include (CheckFunctionExists)
include (CheckCSourceCompiles)
include (CheckCCompilerFlag)

check_type_size(int8_t HAVE_INT8_T)
check_type_size(uint8_t HAVE_UINT8_T)
check_type_size(int16_t HAVE_INT16_T)
check_type_size(uint16_t HAVE_UINT16_T)
check_type_size(uint32_t HAVE_UINT32_T)
check_type_size(int64_t HAVE_INT64_T)
check_type_size(uint64_t HAVE_UINT64_T)

check_type_size(u_int8_t HAVE_U_INT8_T)
check_type_size(u_int16_t HAVE_U_INT16_T)
check_type_size(u_int32_t HAVE_U_INT32_T)
check_type_size(u_int64_t HAVE_U_INT64_T)

#check_function_exists(strndupa HAVE_STRNDUPA)
check_function_exists(strnlen HAVE_STRNLEN)
check_function_exists(popen HAVE_POPEN)
check_function_exists(mkstemp HAVE_MKSTEMP)
check_function_exists(fnmatch HAVE_FNMATCH)

check_c_source_compiles("
#include <alloca.h>
int main() {}" HAVE_ALLOCA_H)

check_include_file(sys/types.h HAVE_SYS_TYPES_H)
check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(stddef.h HAVE_STDDEF_H)

if (WIN32 AND NOT LIBXMP_STATIC)
	add_definitions(-DBUILDING_STATIC)
endif(WIN32 AND NOT LIBXMP_STATIC)

if (WIN32 AND LIBXMP_STATIC)
	add_definitions(-DBUILDING_DLL)
endif (WIN32 AND LIBXMP_STATIC)


if (WIN32)
	include_directories(${CMAKE_SOURCE_DIR}/src/win32)

	# Include the windows-related files.
	file(GLOB WIN_SOURCE_FILES RELATIVE ${CMAKE_SOURCE_DIR} "src/win32/*.c")
	list(APPEND SOURCE_FILES ${WIN_SOURCE_FILES})
	list(SORT SOURCE_FILES)

endif(WIN32)

if (NOT MSVC)
	# We're compiling with a unix-like compiler (eg, gcc, clang, bcc, w/e)
	set(CFLAGS "${CFLAGS} -Wall -Wno-unknown-warning-option -Wno-unused-but-set-variable -Wno-unused-result -Wno-array-bounds")

	check_c_compiler_flag(-xldscope=hidden HAVE_XLDSCOPE_HIDDEN)
	check_c_compiler_flag(-fvisibility=hidden HAVE_VISIBILITY_HIDDEN)

	if(HAVE_XLDSCOPE_HIDDEN)
		set(CFLAGS "${CFLAGS} -xldscope=hidden")
	endif(HAVE_XLDSCOPE_HIDDEN)

	if(HAVE_VISIBILITY_HIDDEN)
		set(CFLAGS "${CFLAGS} -fvisibility=hidden")
		set(LINKFLAGS "${LINKFLAGS} -Wl,--version-script,${CMAKE_SOURCE_DIR}/libxmp.map")
	endif(HAVE_VISIBILITY_HIDDEN)
else(NOT MSVC)
	add_definitions(-DPATH_MAX=1024 -D_USE_MATH_DEFINES -Dinline=__inline)
endif (NOT MSVC)

if (LIBXMP_LITE)

	# Cmake seems to be a bit too retarded to do prefixed lists
	# So this function does such a thing.
	FUNCTION(PREPEND var prefix)
	   SET(listVar "")
	   FOREACH(f ${ARGN})
	      LIST(APPEND listVar "${prefix}/${f}")
	   ENDFOREACH(f)
	   SET(${var} ${listVar} PARENT_SCOPE)
	ENDFUNCTION(PREPEND)

	# This one is a bit more complex, We must make a distributable directory
	# and include a CMakeLists.txt.cmake file to compile that version.
	# We must also copy files and directories from the main source
	# to the subdirectory.
	set(XMPDIR ${CMAKE_BINARY_DIR}/${PROJECT_NAME}-lite-${VERSION_FULL})
	set(BASE_SOURCES virtual.c
					 period.c
					 player.c
					 read_event.c
                     dataio.c
                     lfo.c
                     envelope.c
                     scan.c
                     control.c
                     filter.c
                     effects.c
                     mixer.c
                     mix_all.c
                     load_helpers.c
                     load.c
                     hio.c
                     smix.c
                     memio.c)

    set(BASE_INCLUDES common.h
                      effects.h
                      envelope.h
                      format.h
                      lfo.h
                      list.h
                      mixer.h
                      period.h
                      player.h
                      virtual.h
                      precomp_lut.h
                      hio.h
                      memio.h
                      mdataio.h
                      tempfile.h)

    set(LOADER_SOURCES xm_load.c
                       s3m_load.c
                       it_load.c
                       common.c
                       itsex.c
                       sample.c
                       it.h
                       loader.h
                       mod.h
                       s3m.h
                       xm.h)

    # Cmake is retarded apparently and we must prefix all files ourselves
    PREPEND(LOADER_S ${CMAKE_SOURCE_DIR}/src/loaders ${LOADER_SOURCES})
    PREPEND(BASE_S ${CMAKE_SOURCE_DIR}/src ${BASE_SOURCES} ${BASE_INCLUDES})

	# Make the destination directory
	file(MAKE_DIRECTORY ${XMPDIR})
	# Copy everything in our base directory.
	file(GLOB LITE_DIRECTORY_OBJECTS RELATIVE ${CMAKE_SOURCE_DIR} "lite/*")
	# Remove the config file for the sub-cmake project, This is generated below as
	# CMakeLists.txt and included in the tarball.
	list(REMOVE_ITEM LITE_DIRECTORY_OBJECTS lite/CMakeLists.txt.cmake)
	file(COPY ${LITE_DIRECTORY_OBJECTS} DESTINATION ${XMPDIR})
	# Copy all the source files we need
	file(COPY ${BASE_S} DESTINATION ${XMPDIR}/src/)
	# Copy all the loader files we need
	file(COPY ${LOADER_S} DESTINATION ${XMPDIR}/src/loaders/)
	# Copy the one and only other include file needed.
	file(COPY ${CMAKE_SOURCE_DIR}/include/xmp.h DESTINATION ${XMPDIR}/include/libxmp-lite/)
	# Copy the version mapping file for the linker
	file(COPY ${CMAKE_SOURCE_DIR}/libxmp.map DESTINATION ${XMPDIR})

	# Generate the CMake file prior to allowing ourselves to make a tarball
	configure_file(${CMAKE_SOURCE_DIR}/lite/CMakeLists.txt.cmake ${XMPDIR}/CMakeLists.txt @ONLY)

	# Finally, make a tarball.
	add_custom_target(xmplite ALL COMMAND
        ${CMAKE_COMMAND} -E tar "cJf" "${PROJECT_NAME}-lite-${VERSION_FULL}.tar.xz" "${XMPDIR}")

else(LIBXMP_LITE)
	# We're building regular libXMP
	# Add our include directories
	include_directories(${CMAKE_SOURCE_DIR}/include ${CMAKE_SOURCE_DIR}/src
						${CMAKE_SOURCE_DIR}/loaders ${CMAKE_SOURCE_DIR}/depackers)

	# Finally, tell CMake how to build the project
	#add_executable(${PROJECT_NAME} ${SOURCE_FILES})
	set_source_files_properties(${SOURCE_FILES} PROPERTIES LANGUAGE C COMPILE_FLAGS "${CFLAGS}")
	# Build as static or shared depending on what the user wants
	if (LIBXMP_STATIC)
		add_library(${CMAKE_STATIC_LIBRARY_PREFIX}xmp${CMAKE_STATIC_LIBRARY_SUFFIX} STATIC ${SOURCE_FILES})
		set_target_properties(${CMAKE_STATIC_LIBRARY_PREFIX}xmp${CMAKE_STATIC_LIBRARY_SUFFIX} PROPERTIES LINKER_LANGUAGE C PREFIX "" SUFFIX "" LINK_FLAGS "${LINKFLAGS}")
	endif (LIBXMP_STATIC)

	add_library(${CMAKE_SHARED_LIBRARY_PREFIX}xmp${CMAKE_SHARED_LIBRARY_SUFFIX} SHARED ${SOURCE_FILES})
	set_target_properties(${CMAKE_SHARED_LIBRARY_PREFIX}xmp${CMAKE_SHARED_LIBRARY_SUFFIX} PROPERTIES LINKER_LANGUAGE C PREFIX "" SUFFIX "" LINK_FLAGS "${LINKFLAGS}")


endif(LIBXMP_LITE)
