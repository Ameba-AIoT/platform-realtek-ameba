# app_example/CMakeLists.txt — registers user sources into the SDK.
#
# (A) PIO style: drop .c/.h into ../src/. Auto-bridged by platform-realtek-ameba
#     via the OPTIONAL include() below (file list maintained for you).
# (B) SDK style: list files explicitly with ameba_list_append.
# Both can coexist.

set(private_sources)
set(_pio_src_include_dirs)

ameba_list_append(private_sources app_main.c)

include("${CMAKE_CURRENT_SOURCE_DIR}/_pio_src_fragment.cmake" OPTIONAL)

ameba_add_internal_library(app_example
    p_SOURCES
        ${private_sources}
)

if(_pio_src_include_dirs)
    target_include_directories(${c_CURRENT_TARGET_NAME} PRIVATE ${_pio_src_include_dirs})
endif()
