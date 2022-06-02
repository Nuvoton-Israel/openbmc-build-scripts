#!/bin/bash
#
# Copy test images to remote PC and update Olympus with new image
#
# Usage: update_image.sh
#
set -xeo pipefail

images_path=${images_path:-${WORKSPACE}/images}
rebuild_times=${rebuild_times:-2}

# copy test images to remote PC
cd ${images_path}
test_images="obmc-phosphor-image-${target}.${img_type}.tar"
for i in $(seq 1 "${rebuild_times}");
do
  test_images="${test_images} test_${i}.${img_type}.tar"
done
sshpass -e sftp -oBatchMode=no -b - ${SSHUSER}@${SSHHOST} << !
   put ${test_images} /tftpboot/${target}/
   put bmc_nokernel_image.${img_type}.tar /tftpboot/${target}/
   put bmc_bad_unsig.${img_type}.tar /tftpboot/${target}/
   put bmc_bad_manifest.${img_type}.tar /tftpboot/${target}/
   bye
!

# set up wait time for spi or mmc image
# set default value for SPI
upload_wait=60
reboot_wait=600
reset_wait=300
# mmc need time write data after upload, and reboot time is faster
res=`echo ${img_type} |grep -o mmc`
if [ -n "${res}" ]; then
  echo "use mmc wait"
  upload_wait=120
  reboot_wait=150
  reset_wait=150
fi

# update Olympus firmware via Redfish API
export token=`curl -k -H "Content-Type: application/json" -X POST https://${BMC_IP}/login -d '{"username" :  "root", "password" :  "0penBmc"}' | grep token | awk '{print $2;}' | tr -d '"'`

curl -k -H "X-Auth-Token: $token" -X PATCH -d '{ "HttpPushUriOptions": { "HttpPushUriApplyTime": { "ApplyTime":"OnReset"}}}' https://${BMC_IP}/redfish/v1/UpdateService

curl -k -H "X-Auth-Token: $token" -H "Content-Type: application/octet-stream" -X POST -T ${images_path}/obmc-phosphor-image-${target}.${img_type}.tar https://${BMC_IP}/redfish/v1/UpdateService

echo -e "\nsleep ${upload_wait}"
sleep ${upload_wait}

curl -k -H "X-Auth-Token: $token" -X POST https://${BMC_IP}/redfish/v1/Managers/bmc/Actions/Manager.Reset -d '{"ResetType": "GracefulRestart"}'

echo -e "\nsleep ${reboot_wait}"
sleep ${reboot_wait}

export token=`curl -k -H "Content-Type: application/json" -X POST https://${BMC_IP}/login -d '{"username" :  "root", "password" :  "0penBmc"}' | grep token | awk '{print $2;}' | tr -d '"'`
# get BMC info for check version
curl -k -H "X-Auth-Token: $token" -X GET https://${BMC_IP}/xyz/openbmc_project/software/enumerate

curl -k -H "X-Auth-Token: $token" -X POST https://${BMC_IP}/redfish/v1/Managers/bmc/Actions/Manager.ResetToDefaults -d '{"ResetToDefaultsType": "ResetAll"}'

echo -e "\nsleep ${reset_wait}"
sleep ${reset_wait}
