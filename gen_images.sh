#!/bin/bash

#
# Create bad image for test
#

Usage(){
    echo `basename $0` "[file]"
    echo "  [file]      : the good image file"
    echo "This script will create some bad image file for test automation"
    exit 1
}

print_env(){
    echo "============================="
    echo "TEMP_DIR: ${TEMP_DIR}"
    echo "PRIVATE_KEY: ${PRIVATE_KEY}"
    echo "ROOT_DIR: ${ROOT_DIR}"
    echo "SOURCE_DIR: ${SOURCE_DIR}"
    echo "MANIFEST: ${MANIFEST}"
    echo "VERSION:${VERSION}"
    echo "OUTPUT_HEADER: ${OUTPUT_HEADER}"
    echo "OUTPUT_TAIL: ${OUTPUT_TAIL}"
    echo "INPUT: ${INPUT}"
    echo "============================="
}

fullname(){
    output=${SOURCE_DIR}/${1}
    flist="${flist} ${output}"
}

# default value, modify if need
OPENSSL=openssl
TEMP_DIR=${WORKSPACE}/tmp/pack_source
PRIVATE_KEY=OpenBMC.priv
MANIFEST="${TEMP_DIR}/MANIFEST"
OUTPUT_HEADER=test
# may change later
OUTPUT_TAIL=static.mtd.tar
# should not edit
ROOT_DIR=`dirname "${0}"`
SOURCE_DIR=""
VERSION=""
INPUT=""

# solve relative path, source dir need handle after get path
cd ${ROOT_DIR}
ROOT_DIR=$(pwd)
cd - 1>/dev/null

# ==== check env ====
# openssl util
which ${OPENSSL} 1>/dev/null
if [ "$?" != "0" ];then
    echo "This program need openssl utils, please install..."
    echo "sudo apt install openssl"
    exit 1
fi
# private key
if [ ! -f "${ROOT_DIR}/${PRIVATE_KEY}" ];then
    echo "Cannot find private key: ${ROOT_DIR}/${PRIVATE_KEY}"
    exit 1
fi
if [ ! -f "$1" ];then
    echo "image file is not exist! ${1}"
    Usage
fi
# reset temp dir
if [ -e "${TEMP_DIR}" ];then
    rm -rf "${TEMP_DIR}"
fi
mkdir -p ${TEMP_DIR}
# untar
tar -xf "$1" -C "${TEMP_DIR}"
# handle source dir
SOURCE_DIR=`dirname "$1"`
cd ${SOURCE_DIR}
SOURCE_DIR=$(pwd)
cd - 1>/dev/null
# remove old test data, if exist
# rm -f ${SOURCE_DIR}/${OUTPUT_HEADER}*
# get filename header, but..., name start with test is good for delete
fname=`basename $1`
OUTPUT_TAIL=`echo ${fname} |grep -o '\..*\.*.tar'`
OUTPUT_TAIL=${OUTPUT_TAIL:1}
INPUT=${fname%.${OUTPUT_TAIL}}


# ==== get version ====
VERSION=`grep -o "version=.*" ${MANIFEST}`
print_env


# ==== make error image for auto test ===
cd ${TEMP_DIR}
# no kernel
fullname "bmc_nokernel_image.${OUTPUT_TAIL}"
tar -cf ${output} --exclude=image-* *

# no public key
fullname "bmc_bad_unsig.${OUTPUT_TAIL}"
tar -cf ${output} --exclude=publickey* *

# wrong manifest, remove version to trigger manifest error
fullname "bmc_bad_manifest.${OUTPUT_TAIL}"
sed -i "s/version=.*/version=/g" ${MANIFEST}
openssl dgst -sha256 -sign ${ROOT_DIR}/${PRIVATE_KEY} -out ${MANIFEST}.sig ${MANIFEST}
tar -cf ${output} *

rm -r ${TEMP_DIR}
echo "repack finished..."
echo "out files:${flist}"
