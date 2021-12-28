#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Heather Hsu
## Version 1.0 /2020/02/05
## **All shell data were calculated by dhollander algorithm**
##########################################################################################################################
## 20210123 - copy files from Preprocessed_data
##          - dwi preprocessed only, T1 processing habe been move to step 6
##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage(){
	cat <<EOF

6_CSDpreproc - CSD preprocessing via MRtrix with Dhollanders algorithm.
			   b < Bzero threshold will be considered to null images [default = 10].
		       4_DTIFIT are needed before processing this script.
		       6_CSDpreproc will be created

Usage:	6_CSDpreproc -[options]

System will automatically detect all folders in directory if no input arguments supplied

Options:
	-p 	Input directory; [default = pwd directory]
	-t  Input Bzero threhold; [default = 10];

EOF
exit 1
}

# Setup default variables
OriDir=$(pwd)
Bzerothr=10
run_script=y
args="$(sed -E 's/(-[A-Za-z]+ )([^-]*)( |$)/\1"\2"\3/g' <<< $@)"
declare -a a="($args)"
set - "${a[@]}"

arg=-1

# Parse options
while getopts "hp:t:" optionName;
do
	case $optionName in
	h)
		Usage
		;;
	p)
		OriDir=$OPTARG
		;;
	t)
		Bzerothr=$OPTARG
		;;
	\?)
		exit 42
		;;
	*)
	    echo "Unrecognised option $1" 1>&2
	    exit 1
		;;
	esac
done

# Check if previous step was done -
# Check needed file
if [ ! -d "${OriDir}/Preprocessed_data" ]; then
	echo ""
	echo "Error: Preprocessed_data is not detected."
	echo "Please process previous step..."
	exit 1
fi

if [ ! -d "${OriDir}/5_DTIFIT" ]; then
	echo ""
	echo "Error: 5_DTIFIT is not detected."
	echo "Please process previous step..."
	exit 1
fi


# Check if DWI exists(default: Using resized processed.nii.gz in the Processed_data directory )
handle=dwi_preprocessed_resized
if [[ -f ${OriDir}/Preprocessed_data/${handle}.nii.gz ]] && [[ -f ${OriDir}/Preprocessed_data/${handle}.bval ]] && [[ -f ${OriDir}/Preprocessed_data/${handle}.bvec ]]; then
    :
elif [[ ! -f ${OriDir}/Preprocessed_data/${handle}.nii.gz ]] && [[ -f ${OriDir}/Preprocessed_data/dwi_preprocessed.nii.gz ]] ; then
    handle=dwi_preprocessed
else
        echo ""
        echo "No processed dwi image found..."
        exit 1
fi

# if [ -f "`find ${OriDir}/Preprocessed_data -maxdepth 1 -name "*Average_b0.nii.gz"`" ]; then
# 	handleB0=${OriDir}/5_DTIFIT/*Average_b0.nii.gz
# else
# 	echo ""
# 	echo "No Preprocessed AveragedB0 image found..."
# 	exit 1
# fi

if [ -f "`find ${OriDir}/Preprocessed_data -maxdepth 1 -name "T1w_mask_inDWIspace.nii.gz"`" ]; then
	handleMask=T1w_mask_inDWIspace.nii.gz
else
	echo ""
	echo "No Mask image found..."
	exit 1
fi

if [ -d ${OriDir}/6_CSDpreproc ]; then
	echo ""
	echo "6_CSDpreproc was detected,"
	echo "press y or wait for 10 seconds to continue,"
	echo "press n to terminate the program..."
	read -t 10 -p "y/n : " run_script
	if [ -z "$run_script" ]; then
		run_script=y
	fi
fi

if [ $run_script == "n" ]; then
	echo "System terminated"
	exit 1
fi
if [ $run_script != "y" ]; then
	echo ""
	echo "Error: Input is not valid..."
	exit 1
fi

# Check if DWI exists(default: Using resized processed.nii.gz in the Processed_data directory )
handle=dwi_preprocessed_resized
if [[ -f ${OriDir}/Preprocessed_data/${handle}.nii.gz ]] && [[ -f ${OriDir}/Preprocessed_data/${handle}.bval ]] && [[ -f ${OriDir}/Preprocessed_data/${handle}.bvec ]]; then
    :
elif [[ ! -f ${OriDir}/Preprocessed_data/${handle}.nii.gz ]] && [[ -f ${OriDir}/Preprocessed_data/dwi_preprocessed.nii.gz ]] ; then
    handle=dwi_preprocessed
else
        echo ""
        echo "No processed dwi image found..."
        exit 1
fi


[ -d ${OriDir}/6_CSDpreproc ] || mkdir ${OriDir}/6_CSDpreproc

# S1 CSDproproc
# copy data
cp ${OriDir}/Preprocessed_data/${handle}.nii.gz ${OriDir}/6_CSDpreproc/
cp ${OriDir}/Preprocessed_data/${handle}.bvec ${OriDir}/6_CSDpreproc/
cp ${OriDir}/Preprocessed_data/${handle}.bval ${OriDir}/6_CSDpreproc/
cp ${OriDir}/Preprocessed_data/${handleMask} ${OriDir}/6_CSDpreproc/
mkdir ${OriDir}/6_CSDpreproc/S1_Response

cd ${OriDir}/6_CSDpreproc/
# convert into MRtrix format
mrconvert ${handle}.nii.gz ${OriDir}/6_CSDpreproc/${handle}.mif -fslgrad ${OriDir}/6_CSDpreproc/${handle}.bvec ${OriDir}/6_CSDpreproc/${handle}.bval -quiet

#erode FSL Bet mask - which will generate in step4 (were utilize for mtnormalize)
# maskfilter ${handleMask} erode ${OriDir}/6_CSDpreproc/${handle}-mask-erode.mif -npass 2 #this setting seems to be okay

# detemine shell numbers
shell_num_all=$(mrinfo ${OriDir}/6_CSDpreproc/${handle}.mif -shell_bvalues -config BZeroThreshold ${Bzerothr}| awk '{print NF}')
hb=0
for (( i=1; i<=${shell_num_all}; i=i+1 )); do
	# echo ${i}
	bv=$(mrinfo ${OriDir}/6_CSDpreproc/${handle}.mif -shell_bvalues -config BZeroThreshold ${Bzerothr}| awk '{print $'${i}'}')
	bv_num=$(mrinfo ${OriDir}/6_CSDpreproc/${handle}.mif -shell_sizes -config BZeroThreshold ${Bzerothr}| awk '{print $'${i}'}')
	echo ${bv}
	if [ `echo "${bv} > 1500" | bc` -eq 1 ]; then
		echo "${bv_num} of b=${bv}s/mm^2, high b-value found."
		hb=$((${hb}+1))
	elif [ `echo "${bv} < ${Bzerothr}" | bc` -eq 1 ]; then
		echo "${bv_num} of b=${bv}s/mm^2 (null image(s))"
		null_tmp=$((${null_tmp}+${bv_num}))
		null_shell=$((${null_tmp}+1))
	else
		echo "${bv_num} of b=${bv}s/mm^2"
		lowb_tmp=$((${lowb_tmp}+1))
	fi
done

echo "A total of ${shell_num_all} shells were found..."
if [[ ${null_shell} -eq 0 ]]; then
	echo "No null image was found..."
	exit 1
fi

# dwi2response - shell data were calculated by dhollander algorithm

if [[ ${shell_num_all} -ge 2 ]]; then

	dwi2response dhollander ${OriDir}/6_CSDpreproc/${handle}.mif ${OriDir}/6_CSDpreproc/S1_Response/response_wm.txt ${OriDir}/6_CSDpreproc/S1_Response/response_gm.txt ${OriDir}/6_CSDpreproc/S1_Response/response_csf.txt -config BZeroThreshold ${Bzerothr} -quiet

	if [[ ${shell_num_all} -eq 2 ]]; then
		if [[ ${hb} -eq 0 ]]; then
			echo "lack of high b-value (may cause poor angular resolution)"
		fi

		# for single-shell, 2 tissue
		dwi2fod msmt_csd ${OriDir}/6_CSDpreproc/${handle}.mif ${OriDir}/6_CSDpreproc/S1_Response/response_wm.txt ${OriDir}/6_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/6_CSDpreproc/S1_Response/response_csf.txt ${OriDir}/6_CSDpreproc/S1_Response/odf_csf.mif -mask ${handleMask} -config BZeroThreshold ${Bzerothr} -quiet

		# multi-tissue informed log-domain intensity normalisation
		mtnormalise ${OriDir}/6_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/6_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/6_CSDpreproc/S1_Response/odf_csf.mif ${OriDir}/6_CSDpreproc/S1_Response/odf_csf_norm.mif -mask ${handleMask} -quiet

	else
		#for multi-shell

		dwi2fod msmt_csd ${OriDir}/6_CSDpreproc/${handle}.mif ${OriDir}/6_CSDpreproc/S1_Response/response_wm.txt ${OriDir}/6_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/6_CSDpreproc/S1_Response/response_gm.txt ${OriDir}/6_CSDpreproc/S1_Response/odf_gm.mif ${OriDir}/6_CSDpreproc/S1_Response/response_csf.txt ${OriDir}/6_CSDpreproc/S1_Response/odf_csf.mif -mask ${handleMask} -config BZeroThreshold ${Bzerothr} -quiet

		# multi-tissue informed log-domain intensity normalisation
		mtnormalise ${OriDir}/6_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/6_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/6_CSDpreproc/S1_Response/odf_gm.mif ${OriDir}/6_CSDpreproc/S1_Response/odf_gm_norm.mif ${OriDir}/6_CSDpreproc/S1_Response/odf_csf.mif ${OriDir}/6_CSDpreproc/S1_Response/odf_csf_norm.mif -mask ${handleMask} -quiet
	fi
	# fod2dec ${OriDir}/6_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/6_CSDpreproc/S1_Response/wm_norm_dec.mif
else
	echo "Error: Input is not valid..."
	exit 1
fi
