#include "embedded/vertex_shader.h"
#include "embedded/fragment_shader.h"
#include "embedded/application_logo.h"

#include <cstddef>
#include <fstream>
#include <iostream>
#include <algorithm>

constexpr bool shaders_ok(
    const char* vertex_shader_source, std::size_t vertex_shader_source_size,
    const char* fragment_shader_source, std::size_t fragment_shader_source_size)
{
    return
        // Dummy check
        vertex_shader_source_size > 0 &&
        vertex_shader_source[0] != '\0' &&
        fragment_shader_source_size > 0 &&
        fragment_shader_source[0] != '\0';
}

// Use std::size if you have C++17,
// or if you are using C:
// #define ARRAY_SIZE(array) (sizeof(array) / sizeof(array[0]))
template <typename T, std::size_t N>
constexpr std::size_t array_size(const T (&array)[N])
{
    // Prove that the C approach works as well
    static_assert(N == (sizeof(array) / sizeof(array[0])), "C approach should also work");

    return N;
}

static_assert(shaders_ok(
    embedded_vertex_shader, array_size(embedded_vertex_shader),
    embedded_fragment_shader, array_size(embedded_fragment_shader)),
    "Invalid shaders");

static bool check_original_asset_is_same_as_embedded(const char* asset_begin, const char* asset_end, const char* original_asset_path)
{
    std::ifstream asset_original_file(original_asset_path, std::ios_base::binary);
    if (!asset_original_file.is_open())
    {
        std::cerr << "Cannot open original asset file \"" << original_asset_path << "\"\n";
        return false;
    }

    if (!std::equal(asset_begin, asset_end, std::istreambuf_iterator<char>(asset_original_file), std::istreambuf_iterator<char>{}))
    {
        std::cout << "Failure: original asset file \"" << original_asset_path << "\" does NOT match the embedded one\n";
        return false;
    }
    
    std::cout << "Success: original asset file \"" << original_asset_path << "\" matches the embedded one\n";
    return true;
}

int main()
{
    const bool logo_success = check_original_asset_is_same_as_embedded(
        reinterpret_cast<const char*>(std::begin(embedded_application_logo)),
        reinterpret_cast<const char*>(std::end(embedded_application_logo)),
        "./assets/application_logo.png");

    const bool vertex_shader_success = check_original_asset_is_same_as_embedded(
        std::begin(embedded_vertex_shader),
        std::end(embedded_vertex_shader) - 1 /* exclude null-terminator */,
        "./shaders/dummy_shader.vert");

    const bool fragment_shader_success = check_original_asset_is_same_as_embedded(
        std::begin(embedded_fragment_shader),
        std::end(embedded_fragment_shader) - 1 /* exclude null-terminator */,
        "./shaders/dummy_shader.frag");

    if (logo_success && vertex_shader_success && fragment_shader_success)
        return 0;
    
    return 1;
}
