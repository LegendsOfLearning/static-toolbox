#!/bin/bash
if [ -z "$GITHUB_WORKSPACE" ];then
    echo "GITHUB_WORKSPACE environemnt variable not set!"
    exit 1
fi
if [ "$#" -ne 1 ];then
    echo "Usage: ${0} [x86|x86_64|armhf|aarch64]"
    echo "Example: ${0} x86_64"
    exit 1
fi
set -e
set -o pipefail
set -x
source $GITHUB_WORKSPACE/build/lib.sh
init_lib "$1"

build_socat() {
    # or.cz is down, switching to downloading source
    #fetch "http://repo.or.cz/socat.git" "${BUILD_DIRECTORY}/socat" git
    #fetch "http://www.dest-unreach.org/socat/download/socat-1.7.4.2.tar.gz" "${BUILD_DIRECTORY}/socat" http
    # fetch() using http does not work
    # Manually fetching with http, plus sha verification
    local socat_sha256
    socat_sha256="d697245144731423ddbbceacabbd29447089ea223e9a439b28f9ff90d0dd216e"

    curl -L "http://www.dest-unreach.org/socat/download/socat-1.7.4.3.tar.gz" > /tmp/socat.tar.gz
    echo "${socat_sha256}  /tmp/socat.tar.gz" | sha256sum -c -
    tar -C ${BUILD_DIRECTORY} -zxvf /tmp/socat.tar.gz
    mv ${BUILD_DIRECTORY}/socat-1.7.4.3 ${BUILD_DIRECTORY}/socat
    rm -f /tmp/socat.tar.gz

    cd "${BUILD_DIRECTORY}/socat"
    # git clean -fdx
    autoconf
    CFLAGS="${GCC_OPTS}" \
        CXXFLAGS="${GXX_OPTS}" \
        CPPFLAGS="-I${BUILD_DIRECTORY} -I${BUILD_DIRECTORY}/openssl/include -DNETDB_INTERNAL=-1" \
        LDFLAGS="-L${BUILD_DIRECTORY}/readline -L${BUILD_DIRECTORY}/ncurses/lib -L${BUILD_DIRECTORY}/openssl" \
        ./configure \
            --host="$(get_host_triple)"
    make -j4
    strip socat
}

main() {
    #sudo apt install yodl
    lib_build_openssl
    lib_build_ncurses
    lib_build_readline
    build_socat
    local version
    version=$(get_version "${BUILD_DIRECTORY}/socat/socat -V | grep 'socat version' | awk '{print \$3}'")
    version_number=$(echo "$version" | cut -d"-" -f2)
    cp "${BUILD_DIRECTORY}/socat/socat" "${OUTPUT_DIRECTORY}/socat${version}"
    echo "[+] Finished building socat ${CURRENT_ARCH}"

    echo ::set-output name=PACKAGED_NAME::"socat${version}"
    echo ::set-output name=PACKAGED_NAME_PATH::"${OUTPUT_DIRECTORY}/*"
    echo ::set-output name=PACKAGED_VERSION::"${version_number}"
}

main
