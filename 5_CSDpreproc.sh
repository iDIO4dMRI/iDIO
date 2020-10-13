#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Heather Hsu
## Version 1.0 /2020/02/05
## **All shell data were calculated by dhollander algorithm** 
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage(){
	cat <<EOF

5_CSDpreproc - CSD preprocessing via MRtrix with Dhollanders algorithm.
			   b < Bzero threshold will be considered to null images [default = 10].
		       3_EddyCo and 4_DTIFIT are needed before processing this script.
		       5_CSDpreproc will be created

Usage:	5_CSDpreproc -[options] 

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
	#echo "-$optionName is present [$OPTARG]"
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

# Check if previous step was done
if [ ! -d "${OriDir}/4_DTIFIT" ]; then
	echo ""
	echo "Error: 4_DTIFIT is not detected."
	echo "Please process previous step..."
	exit 1
fi
# Check needed file
if [ -f "`find ${OriDir}/4_DTIFIT -maxdepth 1 -name "*unbiased.nii.gz"`" ]; then
	handleDWI=${OriDir}/4_DTIFIT/*unbiased.nii.gz
	handle=$(basename -- $(find ${OriDir}/4_DTIFIT -maxdepth 1 -name "*unbiased.nii.gz") | cut -f1 -d '.')

else
	echo ""
	echo "No Preprocessed DWI image found..."
	exit 1
fi

if [ -f "`find ${OriDir}/4_DTIFIT -maxdepth 1 -name "*preproc.bval"`" ]; then
	handlebv=$(basename -- $(find ${OriDir}/4_DTIFIT -maxdepth 1 -name "*preproc.bval") | cut -f1 -d '.')
else
	echo ""
	echo "No bvals/bvecs image found..."
	exit 1
fi


if [ -f "`find ${OriDir}/4_DTIFIT -maxdepth 1 -name "*Average_b0.nii.gz"`" ]; then
	handleB0=${OriDir}/4_DTIFIT/*Average_b0.nii.gz
	handleMask=${OriDir}/4_DTIFIT/*b0-brain_mask.nii.gz
else
	echo ""
	echo "No Preprocessed AveragedB0 image found..."
	exit 1
fi

if [ -f "`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*T1w.nii.gz"`" ]; then
	handleT1=${OriDir}/0_BIDS_NIFTI/*T1w.nii.gz
else
	echo ""
	echo "No Preprocessed T1 image found..."
	exit 1
fi

# Subject_ID
# subjid=$(basename ${OriDir})

if [ -d ${OriDir}/5_CSDpreproc ]; then
	echo ""
	echo "5_CSDpreproc was detected,"
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

[ -d ${OriDir}/5_CSDpreproc ] || mkdir ${OriDir}/5_CSDpreproc

## Main Processing
#Generate 5tt (lack: compare 5tt and freesurfer)
mkdir ${OriDir}/5_CSDpreproc/S1_T1proc
mkdir ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix

# 6 degree registration without resampling
flirt -in ${handleT1} -ref ${handleB0} -omat ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_flirt6.mat -dof 6

transformconvert ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_flirt6.mat ${handleT1} ${handleB0} flirt_import ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_mrtrix.txt

mrtransform ${handleT1} ${OriDir}/5_CSDpreproc/S1_T1proc/T12dwispace.nii.gz -linear ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_mrtrix.txt

## 5tt include amygdala and hippocampus
5ttgen fsl -nocrop -sgm_amyg_hipp ${OriDir}/5_CSDpreproc/S1_T1proc/T12dwispace.nii.gz ${OriDir}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -quiet
5tt2gmwmi ${OriDir}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz ${OriDir}/5_CSDpreproc/S1_T1proc/WMGM2dwispace.nii.gz -quiet

# S2 CSDproproc
mkdir ${OriDir}/5_CSDpreproc/S2_Response
cp ${OriDir}/4_DTIFIT/${handlebv}.bvec ${OriDir}/5_CSDpreproc/
cp ${OriDir}/4_DTIFIT/${handlebv}.bval ${OriDir}/5_CSDpreproc/

mrconvert ${handleDWI} ${OriDir}/5_CSDpreproc/${handle}.mif -fslgrad ${OriDir}/5_CSDpreproc/${handlebv}.bvec ${OriDir}/5_CSDpreproc/${handlebv}.bval 

#erode FSL Bet mask
maskfilter ${handleMask} erode ${OriDir}/5_CSDpreproc/${handlebv}-mask-erode.mif -npass 2 #this setting seems to be okay

# detemine shell numbers
shell_num_all=$(mrinfo ${OriDir}/5_CSDpreproc/${handle}.mif -shell_bvalues -config BZeroThreshold ${Bzerothr}| awk '{print NF}')
hb=0
for (( i=1; i<=${shell_num_all}; i=i+1 )); do
	# echo ${i}
	bv=$(mrinfo ${OriDir}/5_CSDpreproc/${handle}.mif -shell_bvalues -config BZeroThreshold ${Bzerothr}| awk '{print $'${i}'}')
	bv_num=$(mrinfo ${OriDir}/5_CSDpreproc/${handle}.mif -shell_sizes -config BZeroThreshold ${Bzerothr}| awk '{print $'${i}'}')
	echo ${bv}
	if [ `echo "${bv} > 1500" | bc` -eq 1 ]; then
		echo "${bv_num} of b=${bv}s/mm^2, high b-value found."
		hb=$((${hb}+1))
	elif [ `echo "${bv} < 66" | bc` -eq 1 ]; then
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


if [[ ${shell_num_all} -ge 2 ]]; then
	# All shell data were calculated by dhollander algorithm

	dwi2response dhollander ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S2_Response/response_wm.txt ${OriDir}/5_CSDpreproc/S2_Response/response_gm.txt ${OriDir}/5_CSDpreproc/S2_Response/response_csf.txt -config BZeroThreshold ${Bzerothr}

	if [[ ${shell_num_all} -eq 2 && ${hb} -eq 0 ]]; then
		echo "lack of high b-value (may cause poor angular resolution)"
	
		# for single-shell, 2 tissue

		dwi2fod msmt_csd ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S2_Response/response_wm.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S2_Response/response_csf.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_csf.mif -mask ${handleMask} -config BZeroThreshold ${Bzerothr}

		# multi-tissue informed log-domain intensity normalisation
		mtnormalise ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S2_Response/odf_wm_norm.mif ${OriDir}/5_CSDpreproc/S2_Response/odf_csf.mif ${OriDir}/5_CSDpreproc/S2_Response/odf_csf_norm.mif -mask ${OriDir}/5_CSDpreproc/${handlebv}-mask-erode.mif

	else	
		#for multi-shell

		dwi2fod msmt_csd ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S2_Response/response_wm.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S2_Response/response_gm.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_gm.mif ${OriDir}/5_CSDpreproc/S2_Response/response_csf.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_csf.mif -mask ${handleMask} -config BZeroThreshold ${Bzerothr}

		# multi-tissue informed log-domain intensity normalisation
		mtnormalise ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S2_Response/odf_wm_norm.mif ${OriDir}/5_CSDpreproc/S2_Response/odf_gm.mif ${OriDir}/5_CSDpreproc/S2_Response/odf_gm_norm.mif ${OriDir}/5_CSDpreproc/S2_Response/odf_csf.mif ${OriDir}/5_CSDpreproc/S2_Response/odf_csf_norm.mif -mask ${OriDir}/5_CSDpreproc/${handlebv}-mask-erode.mif
	fi 

else
	echo " Error: Input is not valid..."
	exit 1
fi
