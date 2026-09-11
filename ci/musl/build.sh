#!/bin/sh
set -eu
cd /work
mkdir -p logs build prefix dist compiler-runtime deps/prefix/lib
trap 'result=$?; if [ "$result" -ne 0 ]; then tail -n 50 /work/logs/*.log; fi' EXIT
apk add --no-cache build-base cmake ninja git curl linux-headers binutils > logs/apk-install.log 2>&1
apk info -v > logs/apk-packages.txt
git config --global --add safe.directory '*'
cp -a /src /work/source
project_name=$(python -c 'import json; print(json.load(open("/src/ci/musl/project.json"))["project"])')
export CMAKE_PREFIX_PATH=/work/deps/prefix
export LD_LIBRARY_PATH=/work/prefix/lib:/work/deps/prefix/lib
python /src/ci/musl/fetch_dependencies.py
set --
case "$project_name" in
  zlib) set -- -DZLIB_BUILD_TESTING=ON ;;
  tinyxml2) set -- -Dtinyxml2_BUILD_TESTING=ON ;;
  qhull) set -- -DLIB_INSTALL_DIR=lib ;;
  assimp) set -- -DASSIMP_BUILD_TESTS=ON -DASSIMP_BUILD_ASSIMP_TOOLS=ON \
    -DASSIMP_BUILD_SAMPLES=OFF -DASSIMP_WARNINGS_AS_ERRORS=OFF -DASSIMP_BUILD_ZLIB=OFF \
    -DZLIB_LIBRARY=/work/deps/prefix/lib/libz.so -DZLIB_INCLUDE_DIR=/work/deps/prefix/include ;;
  *) exit 1 ;;
esac
echo "$(date -u) Configure $project_name"
cmake -S source -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS_RELEASE='-O2 -DNDEBUG' -DCMAKE_CXX_FLAGS_RELEASE='-O2 -DNDEBUG' \
  -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=/work/prefix -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  '-DCMAKE_INSTALL_RPATH=$ORIGIN' -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=ON \
  "$@" > logs/configure.log 2>&1
echo "$(date -u) Compile $project_name"
cmake --build build --parallel 2 > logs/build.log 2>&1
echo "$(date -u) Test $project_name"
if [ "$project_name" = assimp ]; then
  (cd source && /work/build/bin/unit --gtest_output=xml:/work/logs/unit.xml > /work/logs/tests.log 2>&1)
else
  ctest --test-dir build --no-tests=error --output-on-failure --timeout 300 > logs/tests.log 2>&1
fi
cmake --install build > logs/install.log 2>&1
cp -L /usr/lib/libstdc++.so.6 /usr/lib/libgcc_s.so.1 compiler-runtime/
case "$project_name" in
  zlib) link_name=z ;;
  tinyxml2) link_name=tinyxml2 ;;
  qhull) link_name=qhull_r ;;
  assimp) link_name=assimp ;;
esac
c++ /src/ci/musl/smoke.cpp -I/work/prefix/include -L/work/prefix/lib \
  -Wl,-rpath-link,/work/deps/prefix/lib -l"$link_name" -o /work/smoke
/work/smoke > logs/smoke.log 2>&1
python /src/ci/musl/audit.py
python /src/ci/musl/package.py
echo "$(date -u) BUILD_COMPLETE"
