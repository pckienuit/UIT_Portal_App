cmake_minimum_required(VERSION 3.22.1)
project(router_node_bridge)

add_library(router_node_bridge SHARED router_node_bridge.cpp)

add_library(node SHARED IMPORTED)
set_target_properties(node PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_LIST_DIR}/../../../libnode/bin/${ANDROID_ABI}/libnode.so"
)

target_include_directories(router_node_bridge PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}/../../../libnode/include/node"
)

target_compile_features(router_node_bridge PRIVATE cxx_std_17)

find_library(log-lib log)

target_link_libraries(router_node_bridge node ${log-lib})
