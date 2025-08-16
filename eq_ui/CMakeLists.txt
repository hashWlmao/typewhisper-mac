cmake_minimum_required(VERSION 3.20)
project(eq_ui LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)

# Fetch GLFW
FetchContent_Declare(
  glfw
  GIT_REPOSITORY https://github.com/glfw/glfw.git
  GIT_TAG 3.3.9
)
FetchContent_MakeAvailable(glfw)

# Fetch Dear ImGui
FetchContent_Declare(
  imgui
  GIT_REPOSITORY https://github.com/ocornut/imgui.git
  GIT_TAG v1.90.7
)
FetchContent_MakeAvailable(imgui)

# ImGui sources and backends
set(IMGUI_DIR ${imgui_SOURCE_DIR})
set(IMGUI_SOURCES
  ${IMGUI_DIR}/imgui.cpp
  ${IMGUI_DIR}/imgui_draw.cpp
  ${IMGUI_DIR}/imgui_widgets.cpp
  ${IMGUI_DIR}/imgui_tables.cpp
  ${IMGUI_DIR}/imgui_demo.cpp
  ${IMGUI_DIR}/backends/imgui_impl_glfw.cpp
  ${IMGUI_DIR}/backends/imgui_impl_opengl3.cpp
  ${IMGUI_DIR}/libs/gl3w/GL/gl3w.c
)

add_library(imgui_lib ${IMGUI_SOURCES})
target_include_directories(imgui_lib PUBLIC
  ${IMGUI_DIR}
  ${IMGUI_DIR}/backends
  ${IMGUI_DIR}/libs/gl3w
)
# Use gl3w loader
target_compile_definitions(imgui_lib PUBLIC IMGUI_IMPL_OPENGL_LOADER_GL3W)

find_package(OpenGL REQUIRED)

add_executable(eq_ui
  src/main.cpp
  src/GraphicalParametricEQ.hpp
)

target_include_directories(eq_ui PRIVATE src)

target_link_libraries(eq_ui PRIVATE imgui_lib glfw OpenGL::GL)

if(UNIX AND NOT APPLE)
  target_link_libraries(eq_ui PRIVATE dl pthread)
endif()

# On Windows, ensure subsystem is console for now
if(WIN32)
  target_link_libraries(eq_ui PRIVATE opengl32)
endif()