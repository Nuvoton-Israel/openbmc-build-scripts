#!/bin/bash
#
# Re-build openbmc image with different commit and copy to image path
#
# Usage: source this function and execute functions.
#


function rebuild()
{
cd ${obmc_dir}
git commit --amend --no-edit
bitbake -k ${bb_target}
cp ${build_out_image} ${images_path}/test_${1}.${img_type}.tar
}

function rebuild_times()
{
git config --global user.email "user@nuvoton.com"
git config --global user.name "npcm_user"

# clean image folder
rm -rfv ${images_path}
mkdir -p ${images_path}

# copy first build image
cp ${build_out_image} ${images_path}/

for i in $(seq 1 "${1}");
do
  rebuild ${i}
done
}

function create_bad_images()
{
out_file=$(basename ${build_out_image})
# script gen_images must exist
# now we should be ${obmc_dir}/../build
${script_root}/gen_images.sh ${images_path}/${out_file}
}


# script from here
build_out_image="$1"
images_path="$2"
img_type="$3"
obmc_dir="$4"
rebuild_n="$5"
# hard code target 
bb_target=obmc-phosphor-image
# we are now in build.sh
script_root=$(realpath ${obmc_dir}/../openbmc-build-script)

rebuild_times ${rebuild_n}
create_bad_images
