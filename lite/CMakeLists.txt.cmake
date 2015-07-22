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
list(SORT SOURCE_FILES)

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

check_include_file(sys/types.h HAVE_SYS_TYPES_H)
check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(stddef.h HAVE_STDDEF_H)

if (WIN32)
	add_definitions(-DBUILDING_DLL)
endif(WIN32)

# Add our include directories
include_directories(${CMAKE_SOURCE_DIR}/include ${CMAKE_SOURCE_DIR}/src
					${CMAKE_SOURCE_DIR}/src/loaders)

# Finally, tell CMake how to build the project
#add_executable(${PROJECT_NAME} ${SOURCE_FILES})
set_source_files_properties(${SOURCE_FILES} PROPERTIES LANGUAGE C COMPILE_FLAGS "${CFLAGS}")
# Build as static or shared depending on what the user wants
if (LIBXMP_STATIC)
	add_library(xmp-lite STATIC ${SOURCE_FILES})
else (LIBXML_STATIC)
	add_library(xmp-lite SHARED ${SOURCE_FILES})
endif (LIBXMP_STATIC)
