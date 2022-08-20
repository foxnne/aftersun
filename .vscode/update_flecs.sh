cd src/deps/zig-flecs
echo "update_flecs - download build.zig"
curl -O https://raw.githubusercontent.com/foxnne/zig-flecs-test/main/build.zig

cd src
echo "update_flecs - download flecs.zig"
curl -O https://raw.githubusercontent.com/foxnne/zig-flecs-test/main/src/flecs.zig
curl -O https://raw.githubusercontent.com/foxnne/zig-flecs-test/main/src/c.zig

cd c
echo "update_flecs - download flecs.h and flecs.c"
curl -O https://raw.githubusercontent.com/foxnne/zig-flecs-test/main/src/c/flecs.h
curl -O https://raw.githubusercontent.com/foxnne/zig-flecs-test/main/src/c/flecs.c

echo "update_flecs done"