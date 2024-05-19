#! /vendor/bin/sh
#=============================================================================
# Copyright (c) 2019-2021 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#=============================================================================

VENDOR_DIR="/vendor/lib/modules"
#for gki2.0 /vendor/lib/modules will link to /vendor_dlkm/lib/modules
#also /odm/lib/modules will link to /odm_dlkm/lib/modules
#VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules"

#ifdef USING_ODM_DLKM
#HuangQiujun@KERNEL.BSP, 2021/08/25: support gki2.0 odm_dlkm partition
ODM_DIR="/odm/lib/modules"
#endif USING_ODM_DLKM

MODPROBE="/vendor/bin/modprobe"

# vendor modules partition could be /vendor/lib/modules
# odm modules partition could be /odm/lib/modules
POSSIBLE_DIRS="${VENDOR_DIR} ${ODM_DIR}"
RET=1

#ifdef OPLUS_FEATURE_CAMERA_COMMON
#maohong@cam.drv, 2022/06/03,
#Add for ftm mode do not check senosr probe result
if [ "$(cat /sys/systeminfo/ftmmode)" == "3" ]; then
	setprop vendor.camera.ftmmode 3
fi
#endif /* OPLUS_FEATURE_CAMERA_COMMON */

for dir in ${POSSIBLE_DIRS} ;
do
	if [ ! -e ${dir}/modules.load ]; then
		continue
	fi
	if [ -e ${dir}/modules.blocklist ]; then
		blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.blocklist | sed -e 's/-/_/g' -e 's/^/-e /')"
	else
		# Use pattern that won't be found in modules list so that all modules pass through grep below
		blocklist_expr="-e %"
	fi
	#ifdef OPLUS_BUG_STABILITY
	#LiuZuofa@CONNECTIVITY.WIFI.HARDWARE.FTM, 2021/10/30,
	#Add for ftm mode do not probe qca_cld3_qca6490 ko
	if [ "$(cat /sys/systeminfo/ftmmode)" == "3" ]; then
		blocklist_expr+=" -e qca_cld3_qca6490"
	fi
	#endif /* OPLUS_BUG_STABILITY */
	# Filter out modules in blocklist - we would see unnecessary errors otherwise
	load_modules=$(cat ${dir}/modules.load | grep -w -v ${blocklist_expr})
	first_module=$(echo ${load_modules} | cut -d " " -f1)
	other_modules=$(echo ${load_modules} | cut -d " " -f2-)
	if ! ${MODPROBE} -b -s -d ${dir} -a ${first_module} > /dev/null ; then
		continue
	fi
	# load modules individually in case one of them fails to init
	for module in ${other_modules}; do
		( ${MODPROBE} -b -s -d ${dir} -a ${module} > /dev/null ) &
	done

	wait

	if [ "${dir}" == "${VENDOR_DIR}" ]; then
		RET=0
	fi
done

if [ ${RET} -eq 0 ]; then
	setprop vendor.all.modules.ready 1
fi

exit ${RET}
