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

5_CSDpreproc - CSD preprocessing via MRtrix. b < 65s/mm^2 will be considered to null images.
		    3_EddyCo and 4_DTIFIT are needed before processing this script.
		    5_CSDpreproc will be created

Usage:	5_CSDpreproc -[options] 

System will automatically detect all folders in directory if no input arguments supplied

Options:
	-p 	Input directory; [default = pwd directory]

EOF
exit 1
}

# Setup default variables
OriDir=$(pwd)
run_script=y
args="$(sed -E 's/(-[A-Za-z]+ )([^-]*)( |$)/\1"\2"\3/g' <<< $@)"
declare -a a="($args)"
set - "${a[@]}"

arg=-1

# Parse options
while getopts "hp:" optionName; 
do
	#echo "-$optionName is present [$OPTARG]"
	case $optionName in
	h)  
		Usage
		;;
	p)
		OriDir=$OPTARG
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

if [ -f "`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*T1.nii.gz"`" ]; then
	handleT1=${OriDir}/0_BIDS_NIFTI/*T1.nii.gz
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

# echo ${handleT1}
# echo ${handleB0}
# echo ${handleDWI}


### BE CAREFUL ###
# Adding bzero threshold into configure file
# Will CREATE the new configure file and RENAME the old configure files into ${conf}.back
cd ~/
if [[ -f .mrtrix.conf ]]; then 
	for file in .mrtrix.conf*; do
		cp ${file} ${file}.back
	done
	echo "BZeroThreshold: 66" > .mrtrix.conf
else
echo "BZeroThreshold: 66">.mrtrix.conf # with a threshold of 65 (HCP 7T b0 <=65)
#default shell tolerance = 80 (BValueEpsilon: 80)
fi

## Main Processing
#Generate 5tt (lack: compare 5tt and freesurfer)
mkdir ${OriDir}/5_CSDpreproc/S1_T1proc
mkdir ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix

# 6 degree registration without resampling
flirt -in ${handleT1} -ref ${handleB0} -omat ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_flirt6.mat -dof 6

transformconvert ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_flirt6.mat ${handleT1} ${handleB0} flirt_import ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_mrtrix.txt

mrtransform ${handleT1} ${OriDir}/5_CSDpreproc/S1_T1proc/T12dwispace.nii.gz -linear ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_mrtrix.txt

## 5tt include amygdala and hippocampus
# 5ttgen fsl -nocrop ${OriDir}/5_CSDpreproc/S1_T1proc/T12dwispace.nii.gz ${OriDir}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -quiet
5ttgen fsl -nocrop -sgm_amyg_hipp ${OriDir}/5_CSDpreproc/S1_T1proc/T12dwispace.nii.gz ${OriDir}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -quiet
5tt2gmwmi ${OriDir}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz ${OriDir}/5_CSDpreproc/S1_T1proc/WMGM2dwispace.nii.gz -quiet

# S2 CSDproproc
mkdir ${OriDir}/5_CSDpreproc/S2_Response
cp ${OriDir}/4_DTIFIT/${handlebv}.bvec ${OriDir}/5_CSDpreproc/
cp ${OriDir}/4_DTIFIT/${handlebv}.bval ${OriDir}/5_CSDpreproc/

mrconvert ${handleDWI} ${OriDir}/5_CSDpreproc/${handle}.mif -fslgrad ${OriDir}/5_CSDpreproc/${handlebv}.bvec ${OriDir}/5_CSDpreproc/${handlebv}.bval 

# # doing bias correct
# dwibiascorrect -ants ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/${handle}-unbiased.mif
# not producing the b0 mask via MRTRIX, using bet instead
# dwi2mask ${OriDir}/5_CSDpreproc/${handle}-unbiased.mif ${OriDir}/5_CSDpreproc/dwi_mask.mif -fslgrad ${OriDir}/5_CSDpreproc/${handle}.bvec ${OriDir}/5_CSDpreproc/${handle}.bval 

# detemine shell numbers
shell_num_all=$(mrinfo ${OriDir}/5_CSDpreproc/${handle}.mif -shell_bvalues| awk '{print NF}')
hb=0
for (( i=1; i<=${shell_num_all}; i=i+1 )); do
	# echo ${i}
	bv=$(mrinfo ${OriDir}/5_CSDpreproc/${handle}.mif -shell_bvalues| awk '{print $'${i}'}')
	bv_num=$(mrinfo ${OriDir}/5_CSDpreproc/${handle}.mif -shell_sizes| awk '{print $'${i}'}')
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
	# for single-shell data 

	# dwi2response tournier ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S2_Response/response_wm.txt 

	# dwi2fod msmt_csd ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S2_Response/response_wm.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S2_Response/response_csf.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_csf.mif -mask ${handleMask}
# elif [[ ${shell_num_all} -ge 3 ]]; then
	if [[ ${shell_num_all} -eq 2 && ${hb} -eq 0 ]]; then
		echo "lack of high b-value (may cause poor angular resolution)"
	fi
	# for multi-shell data
	dwi2response dhollander ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S2_Response/response_wm.txt ${OriDir}/5_CSDpreproc/S2_Response/response_gm.txt ${OriDir}/5_CSDpreproc/S2_Response/response_csf.txt

	dwi2fod msmt_csd ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S2_Response/response_wm.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S2_Response/response_gm.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_gm.mif ${OriDir}/5_CSDpreproc/S2_Response/response_csf.txt ${OriDir}/5_CSDpreproc/S2_Response/odf_csf.mif -mask ${handleMask}
else
	echo " Error: Input is not valid..."
	exit 1
fi

#S4 generate Track
mkdir ${OriDir}/5_CSDpreproc/S3_Tractography
tckgen ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S3_Tractography/track_DynamicSeed_1M.tck -act ${OriDir}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -backtrack -crop_at_gmwmi -seed_dynamic ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif -maxlength 250 -minlength 5 -mask ${handleMask} -select 1M

tcksift2 ${OriDir}/5_CSDpreproc/S3_Tractography/track_DynamicSeed_1M.tck ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S3_Tractography/SIFT2_weights.txt -act ${OriDir}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -out_mu ${OriDir}/5_CSDpreproc/S3_Tractography/SIFT_mu.txt

