#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Shintai Chong & HeatherHsu
## Version 1.0 /2020/06/05
##
##########################################################################################################################

# 20200417 - fix floating number b-values comparison
#          - fix null and lowb as 0 and 1000 (select_dwi_vols_st)
# 20200424 - cancle fixing null and lowb as 0 and 1000
#		   - convert floating number to integer
# 20200605 - change shell detecting - using MRtrix (-s function remove)
# 20200825 - adapting without configure files (-t add Bzerothr function)
# 20200907 - bug fixed: ${Bzerothr}

##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage(){
	cat <<EOF

4_DTIFIT - Diffusion Tensor model fitting function. Only low-b (<1500s/mm^2) images were used for fitting. 
		   b < Bzero threshold will be considered to null images [default = 10].
		   2_BiasCo and 3_EddyCo are needed before processing this script.
		   4_DTIFIT will be created

Usage:	4_DTIFIT -[options] 

System will automatically detect all folders in directory if no input arguments supplied

Options:
	-p 	Input directory; [default = pwd directory]
	-t  Input Bzero threshold; [default = 10]; 

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
if [ ! -d "${OriDir}/3_EddyCo" ] || [ ! -d "${OriDir}/2_BiasCo" ]; then
	echo ""
	echo "Error: 2_BiasCo or 3_EddyCo are not detected."
	echo "Please process previous step..."
	exit 1
fi

# Check if DWI exists 
if [ -f "`find ${OriDir}/3_EddyCo -maxdepth 1 -name "*EddyCo.nii.gz*"`" ]; then
	handle=$(basename -- $(find ${OriDir}/3_EddyCo -maxdepth 1 -name "*EddyCo.nii.gz*") | cut -f1 -d '.')
else
	echo ""
	echo "No EddyCo image found..."
	exit 1
fi

# Subject_ID
subjid=$(basename ${OriDir})

if [ -d ${OriDir}/4_DTIFIT ]; then
	echo ""
	echo "4_DTIFIT was detected,"
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

[ -d ${OriDir}/4_DTIFIT ] || mkdir ${OriDir}/4_DTIFIT

cp ${OriDir}/3_EddyCo/${handle}.nii.gz ${OriDir}/4_DTIFIT/${subjid}-preproc.nii.gz
cp ${OriDir}/3_EddyCo/${handle}.bval ${OriDir}/4_DTIFIT/${subjid}-preproc.bval
cp ${OriDir}/3_EddyCo/${handle}.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc.bvec

# Doing bias correct
dwibiascorrect ants ${OriDir}/4_DTIFIT/${subjid}-preproc.nii.gz ${OriDir}/4_DTIFIT/${subjid}-preproc-unbiased.nii.gz -fslgrad ${OriDir}/4_DTIFIT/${subjid}-preproc.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc.bval -force

cd ${OriDir}/4_DTIFIT

# detemine shell numbers
shell_num_all=$(mrinfo ${OriDir}/4_DTIFIT/${subjid}-preproc-unbiased.nii.gz -fslgrad ${OriDir}/4_DTIFIT/${subjid}-preproc.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc.bval -shell_bvalues -config BZeroThreshold ${Bzerothr} | awk '{print NF}')

echo "A total of ${shell_num_all} b-values were found..."

lowb_tmp=0
null_tmp=0
for (( i=1; i<=${shell_num_all}; i=i+1 )); do
# echo ${i}
	bv=$(mrinfo ${OriDir}/4_DTIFIT/${subjid}-preproc-unbiased.nii.gz -fslgrad ${OriDir}/4_DTIFIT/${subjid}-preproc.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc.bval -shell_bvalues -config BZeroThreshold ${Bzerothr} | awk '{print $'${i}'}')
	bv_num=$(mrinfo ${OriDir}/4_DTIFIT/${subjid}-preproc-unbiased.nii.gz -fslgrad ${OriDir}/4_DTIFIT/${subjid}-preproc.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc.bval -shell_sizes -config BZeroThreshold ${Bzerothr} | awk '{print $'${i}'}')
	echo ${bv}
	if [ `echo "${bv} > 1500" | bc` -eq 1 ]; then
		tput setaf 1 # change terminal color to red color
		echo "${bv_num} of b=${bv}s/mm^2, high b-value found."
		tput sgr0 # change terminal color to default color

	elif [ `echo "${bv} < ${Bzerothr}" | bc` -eq 1 ]; then
		echo "${bv_num} of b=${bv}s/mm^2 (null image(s))"
		null_tmp=$((${null_tmp}+${bv_num}))
	else
		echo "${bv_num} of b=${bv}s/mm^2"
		lowb_tmp=$((${lowb_tmp}+1))
		lowb[${lowb_tmp}]=${bv}
	fi
done

if [[ ${null_tmp} -eq 0 ]]; then
	echo "No null image was found..."
	exit 1
fi

# Average DWI null images
dwiextract ${OriDir}/4_DTIFIT/${subjid}-preproc-unbiased.nii.gz - -fslgrad ${OriDir}/4_DTIFIT/${subjid}-preproc.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc.bval -bzero -config BZeroThreshold ${Bzerothr} | mrmath - mean -axis 3 ${OriDir}/4_DTIFIT/${subjid}-preproc-Average_b0.nii.gz

# Extract DWI low-b images
tags=""
if [ ${#lowb[*]} -eq 1 ]; then
	tags=${lowb[1]}
elif [ ${#lowb[*]} -gt 1 ]; then
	for ((i=1; i<${#lowb[*]}; i++)); do
	 	tags="${tags},${lowb[$i]}"
	done
fi
echo bvalue ${tags}

dwiextract ${OriDir}/4_DTIFIT/${subjid}-preproc-unbiased.nii.gz -fslgrad ${OriDir}/4_DTIFIT/${subjid}-preproc.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc.bval -no_bzero -shells ${tags} ${OriDir}/4_DTIFIT/${subjid}-preproc-lowb-only-data.nii.gz -export_grad_fsl ${OriDir}/4_DTIFIT/${subjid}-preproc-lowb-only-data.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc-lowb-only-data.bval -config BZeroThreshold ${Bzerothr} 

cd ${OriDir}/4_DTIFIT
fslmerge -t ${subjid}-preproc-lowb-data.nii.gz ${subjid}-preproc-Average_b0.nii.gz ${subjid}-preproc-lowb-only-data.nii.gz 
echo 0 > b0
paste -d ' ' b0 ${subjid}-preproc-lowb-only-data.bval > ${subjid}-preproc-lowb-data.bval
echo 0 >> b0
echo 0 >> b0
paste -d ' ' b0 ${subjid}-preproc-lowb-only-data.bvec > ${subjid}-preproc-lowb-data.bvec

bet ${subjid}-preproc-Average_b0.nii.gz ${subjid}-preproc-Average_b0-brain -f 0.2 -m

dtifit -k ${subjid}-preproc-lowb-data.nii.gz -o ${subjid} -m ${subjid}-preproc-Average_b0-brain_mask.nii.gz -r ${subjid}-preproc-lowb-data.bvec -b ${subjid}-preproc-lowb-data.bval

fslmaths ${subjid}_L2.nii.gz -add ${subjid}_L3 ${subjid}_RD_tmp.nii.gz
fslmaths ${subjid}_RD_tmp.nii.gz -div 2 ${subjid}_RD.nii.gz

rm -f b0 ${subjid}-preproc-lowb-only-data.bval ${subjid}-preproc-lowb-only-data.bvec ${subjid}-preproc-lowb-only-data.nii.gz ${subjid}_RD_tmp.nii.gz