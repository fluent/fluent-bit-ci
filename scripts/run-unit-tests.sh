#!/bin/bash

# Really should not rely on PWD here
SOURCE_DIR=${SOURCE_DIR:-$PWD}
nparallel=$(( $(getconf _NPROCESSORS_ONLN) > 8 ? 8 : $(getconf _NPROCESSORS_ONLN) ))

[ -x /usr/bin/llvm-symbolizer-5.0 ] && export ASAN_SYMBOLIZER_PATH=/usr/bin/llvm-symbolizer-5.0
[ -x /usr/local/clang-5.0.0/bin/llvm-symbolizer ] && export ASAN_SYMBOLIZER_PATH=/usr/local/clang-5.0.0/bin/llvm-symbolizer
[ -x /usr/bin/llvm-symbolizer-6.0 ] && export ASAN_SYMBOLIZER_PATH=/usr/bin/llvm-symbolizer-6.0
[ -x /usr/bin/llvm-symbolizer ] && export ASAN_SYMBOLIZER_PATH=/usr/bin/llvm-symbolizer

echo "use $ASAN_SYMBOLIZER_PATH"

SKIP_TESTS="flb-rt-out_elasticsearch
flb-rt-out_td
flb-rt-out_forward
flb-rt-in_disk
flb-rt-in_proc"

# On macOS, kubernetes log directory which points to /var/log does not exist.
if [ "$(uname)" = "Darwin" ]
then
    SKIP_TESTS+="flb-rt-filter_kubernetes"
fi

for skip in $SKIP_TESTS
do
    SKIP="$SKIP -DFLB_WITHOUT_${skip}=1"
done

SKIP="$SKIP -DFLB_WITHOUT_flb-it-fstore=1"
# If no v6, disable that test
if command -v ip &> /dev/null;
then
    [[ ! $(ip a) =~ ::1 ]] && SKIP="$SKIP -DFLB_WITHOUT_flb-it-network=1"
else
    [[ ! $(ifconfig) =~ ::1 ]] && SKIP="$SKIP -DFLB_WITHOUT_flb-it-network=1"
fi

GLOBAL_OPTS="-DFLB_BACKTRACE=Off -DFLB_SHARED_LIB=Off -DFLB_DEBUG=On -DFLB_ALL=On -DFLB_EXAMPLES=Off"

# On macOS, OpenSSL's root directory should be specified with -DOPENSSL_ROOT_DIR.
if [ "$(uname)" = "Darwin" ]
then
    GLOBAL_OPTS+=" -DOPENSSL_ROOT_DIR=$(brew --prefix openssl)"
fi

set -e
mkdir -p "$SOURCE_DIR"/build
pushd "$SOURCE_DIR"/build || exit 1
echo "Build unit tests for $FLB_OPT on $nparallel VCPU"
echo "cmake $LDFLAG $GLOBAL_OPTS $FLB_OPT -DFLB_TESTS_INTERNAL=On -DFLB_TESTS_RUNTIME=On $SKIP ../"
# We do want splitting for parameters here
# shellcheck disable=SC2086
cmake $LDFLAG $GLOBAL_OPTS $FLB_OPT -DFLB_TESTS_INTERNAL=On -DFLB_TESTS_RUNTIME=On $SKIP ../
make -j $nparallel

echo
echo "Run unit tests for $FLB_OPT on $nparallel VCPU"
echo
ctest -j $nparallel --build-run-dir "$SOURCE_DIR"/build --output-on-failure
res=$?

if [[ "$FLB_OPT" =~ COVERAGE  ]]
then
    mkdir -p "$SOURCE_DIR"/coverage
    find lib \( -name "*.gcda" -o -name "*.gcno" \) -print0 | xargs -0 -r rm
    gcovr -e "build/sql.l" -e "build/sql.y" -e "build/ra.l" -e "build/ra.y" -p -r .. . | cut -c1-100
    gcovr -e "build/sql.l" -e "build/sql.y" -e "build/ra.l" -e "build/ra.y" --html --html-details -p -r .. -o "$SOURCE_DIR"/coverage/index.html .
    echo
    echo "See coverage/index.html for code-coverage details"
fi
popd || true

exit $res
