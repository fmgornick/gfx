#!/bin/sh

frameworks=(
    "-framework AppKit"
    "-framework Foundation"
    "-framework Metal"
    "-framework MetalKit"
    "-framework ModelIO"
)

# compile shaders
xcrun metal shaders.metal -o shaders.metallib

# compile obj-c code into dynamic library
clang -fPIC -shared metal.m -o libmetal.dylib ${frameworks[@]}

# compile c code into binary linking obj-c part
clang -L. -Wl,-rpath,. main.c -o gfx -lmetal
