cmake_minimum_required(VERSION 2.8)

# Force external build
if(${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_BINARY_DIR} AND NOT WIN32)
	message(FATAL_ERROR "You can not use CMake to build from the root of it's source tree! Remove the CMakeCache.txt file from this directory, then create a separate directory (either below this directory or elsewhere), and then re-run CMake from there.")
endif(${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_BINARY_DIR} AND NOT WIN32)

# Project version
SET(PROJECT_MAJOR_VERSION @PROJECT_MAJOR_VERSION@)
SET(PROJECT_MINOR_VERSION @PROJECT_MINOR_VERSION@)
SET(PROJECT_PATCH_LEVEL @PROJECT_PATCH_LEVEL@)
SET(VERSION_SIMPLE "@VERSION_SIMPLE@")
SET(VERSION_FULL "@VERSION_FULL@")
SET(VERSION_GIT "@VERSION_GIT@")

# Finally initialize our project
project(libxmp-lite C)

file(GLOB SOURCE_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "src/*.c")
file(GLOB LOADER_SOURCES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "src/loaders/*.c")
list(APPEND SOURCE_FILES ${LOADER_SOURCES})
list(SORT SOURCE_FILES)

# Build static or shared? OFF = shared, ON = static
option(LIBXMP_STATIC "Build the library as static" OFF)
# Disable Impuse Tracker support
option(LIBXMP_NO_IT_SUPPORT "Build without Impulse Tracker (.IT files) support" OFF)

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

check_include_file(sys/types.h HAVE_SYS_TYPES_H)
check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(stddef.h HAVE_STDDEF_H)

if (WIN32 AND NOT LIBXMP_STATIC)
	add_definitions(-DBUILDING_STATIC)
endif(WIN32 AND NOT LIBXMP_STATIC)

if (WIN32 AND LIBXMP_STATIC)
	add_definitions(-DBUILDING_DLL)
endif (WIN32 AND LIBXMP_STATIC)

if (LIBXMP_NO_IT_SUPPORT)
	add_definitions(-DLIBXMP_CORE_DISABLE_IT)
endif(LIBXMP_NO_IT_SUPPORT)

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

	if (LIBXMP_STATIC)
		# Fix microsoft's dual-runtime crap that CMake seems to fuck up.
		set(CompilerFlags CMAKE_C_FLAGS
	        			  CMAKE_C_FLAGS_DEBUG
	        			  CMAKE_C_FLAGS_MINSIZEREL
	        			  CMAKE_C_FLAGS_RELEASE
	        			  CMAKE_C_FLAGS_RELWITHDEBINFO)

		foreach(CompilerFlag ${CompilerFlags})
			string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
		endforeach(CompilerFlag ${CompilerFlags})
	endif(LIBXMP_STATIC)

endif (NOT MSVC)

add_definitions(-D_REENTRANT -DLIBXMP_CORE_PLAYER)

# Add our include directories
include_directories(${CMAKE_SOURCE_DIR}/include/libxmp-lite ${CMAKE_SOURCE_DIR}/src
					${CMAKE_SOURCE_DIR}/src/loaders)

# Finally, tell CMake how to build the project
# FIXME: This might need to be changed to allow /MD or /MT at the discression of the build.
set_source_files_properties(${SOURCE_FILES} PROPERTIES LANGUAGE C COMPILE_FLAGS "${CFLAGS}")
# Build as static or shared depending on what the user wants
if (LIBXMP_STATIC)
	# Build a .lib
	add_library(${CMAKE_STATIC_LIBRARY_PREFIX}xmp-lite${CMAKE_STATIC_LIBRARY_SUFFIX} STATIC ${SOURCE_FILES})
	set_target_properties(${CMAKE_STATIC_LIBRARY_PREFIX}xmp-lite${CMAKE_STATIC_LIBRARY_SUFFIX} PROPERTIES LINKER_LANGUAGE C PREFIX "" SUFFIX "" LINK_FLAGS "${LINKFLAGS}")
else(LIBXMP_STATIC)
	# Build a .dll
	add_library(${CMAKE_SHARED_LIBRARY_PREFIX}xmp-lite${CMAKE_SHARED_LIBRARY_SUFFIX} SHARED ${SOURCE_FILES})
	set_target_properties(${CMAKE_SHARED_LIBRARY_PREFIX}xmp-lite${CMAKE_SHARED_LIBRARY_SUFFIX} PROPERTIES LINKER_LANGUAGE C PREFIX "" SUFFIX "" LINK_FLAGS "${LINKFLAGS}")
endif (LIBXMP_STATIC)
