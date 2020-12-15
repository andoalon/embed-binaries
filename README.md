# embed-binaries

Easy-to-use CMake utility to generate C/C++ code containing binary data from files.
Useful when you want to avoid shipping extra files, but you want to still have them separately during development.

## Features

* Generates arrays containing binary data as C/C++ source files
* Single CMake file with no dependencies except CMake >=3.17.5. Copy the file to your project and start using it!
* Generated source files are updated at compile-time whenever the original asset gets modified (CMake's `add_custom_command` is used)
* Platform-independent, as all of the implementation is written in CMake
* Can optionally generate a `constexpr` array for compile-time manipulation in C++

## Example

```cmake
embed_binaries(my-embedded-binaries
    ASSET
        NAME "vertex_shader"
        PATH "shaders/dummy_shader.vert"

        # With the "constexpr" 'MODE', a constexpr array is
        # generated in the header so that we can use the
        # embedded data in a constexpr context (C++).
        #
        # If no 'MODE' or 'MODE extern' is specified,
        # an extern const array will be declared in the header,
        # with the contents in a corresponding .c file,
        # which makes the header as short as possible, which
        # improves compile time, especially when embedding larger assets
        MODE constexpr
    ASSET
        NAME "fragment_shader"
        PATH "shaders/dummy_shader.frag"
        MODE constexpr
    ASSET
        NAME "application_logo"
        PATH "assets/application_logo.png"
        # We don't specify 'MODE'. Equivalent to:
        # MODE extern
)
```
