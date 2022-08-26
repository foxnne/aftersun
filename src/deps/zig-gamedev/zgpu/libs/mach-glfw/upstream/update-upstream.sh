#!/usr/bin/env bash
set -ex

# GLFW
rm -rf glfw/
git clone --depth 1 --branch master https://github.com/glfw/glfw
cd glfw/
git rev-parse HEAD > ../VERSION

# Remove non-C files
rm -rf .appveyor.yml .git .github .gitattributes .gitignore .mailmap .travis.yml
rm **/*.cmake.in README.md CONTRIBUTORS.md
rm -r CMake* deps/ examples/ tests/ docs/
rm src/CMakeLists.txt src/*.in

# Vulkan headers
cd ..
rm -rf vulkan_headers/
git clone --depth 1 https://github.com/KhronosGroup/Vulkan-Headers vulkan_headers/
cd vulkan_headers
git rev-parse HEAD > ../VULKAN_HEADERS_VERSION
rm -rf .git .github registry/ *.gn *.txt *.md cmake/ 
rm -rf include/vk_video
rm .cmake-format.py .gitattributes .gitignore
