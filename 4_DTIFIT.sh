#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Shintai Chong
## Version 1.0 /2020/02/05
##
##########################################################################################################################

# 20200417 - fix floating number b-values comparison
#          - fix null and lowb as 0 and 1000 (select_dwi_vols_st)
# 20200424 - cancle fixing null and lowb as 0 and 1000
#		   - convert floating number to integer
# 20200507 - Adding bias correction, L121
##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage(){
	cat <<EOF

4_DTIFIT - Diffusion Tensor model fitting function. Only low-b (<1500s/mm^2) images were used for fitting. b <65s/mm^2 will be considered to null images.
		    2_BiasCo and 3_EddyCo are needed before processing this script.
		    4_DTIFIT will be created

Usage:	4_DTIFIT -[options] 

System will automatically detect all folders in directory if no input arguments supplied

Options:
	-p 	Input directory; [default = pwd directory]
	-s  funtion "select_dwi_vols_st" path

EOF
exit 1
}

# Setup default variables
OriDir=$(pwd)
run_script=y
mainS=$(pwd)
args="$(sed -E 's/(-[A-Za-z]+ )([^-]*)( |$)/\1"\2"\3/g' <<< $@)"
declare -a a="($args)"
set - "${a[@]}"

arg=-1

# Parse options
while getopts "hp:s:" optionName; 
do
	#echo "-$optionName is present [$OPTARG]"
	case $optionName in
	h)  
		Usage
		;;
	p)
		OriDir=$OPTARG
		;;
	s)
		mainS=$OPTARG
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
if [ -f "`find ${OriDir}/2_BiasCo -maxdepth 1 -name "*DriftCo.nii.gz*"`" ]; then
	handle=$(basename -- $(find ${OriDir}/2_BiasCo -maxdepth 1 -name "*DriftCo.nii.gz*") | cut -f1 -d '.')
elif [ -f "`find ${OriDir}/2_BiasCo -maxdepth 1 -name "*deGibbs.nii.gz*"`" ]; then
	handle=$(basename -- $(find ${OriDir}/2_BiasCo -maxdepth 1 -name "*deGibbs.nii.gz*") | cut -f1 -d '.')
else
	echo ""
	echo "No image found..."
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

cp ${OriDir}/3_EddyCo/${handle}-EddyCo.nii.gz ${OriDir}/4_DTIFIT/${subjid}-preproc.nii.gz
cp ${OriDir}/3_EddyCo/${handle}-EddyCo.bval ${OriDir}/4_DTIFIT/${subjid}-preproc.bval
cp ${OriDir}/3_EddyCo/${handle}-EddyCo.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc.bvec

# Doing bias correct
dwibiascorrect ants ${OriDir}/4_DTIFIT/${subjid}-preproc.nii.gz ${OriDir}/4_DTIFIT/${subjid}-preproc-unbiased.nii.gz -fslgrad ${OriDir}/4_DTIFIT/${subjid}-preproc.bvec ${OriDir}/4_DTIFIT/${subjid}-preproc.bval -force

cd ${OriDir}/4_DTIFIT
bv_num=($(grep '[^[:blank:]]+' -Eo ${subjid}-preproc.bval | sort | uniq -c))
echo "A total of $(($(echo ${#bv_num[@]}) / 2)) b-values were found..."
lowb_tmp=0
null_tmp=0
for ((i=0; i<${#bv_num[@]}; i=i+2)); do
	if [ ${bv_num[$(($i+1))]} -gt 1500 ]; then
		tput setaf 1 # change terminal color to red color
		echo "${bv_num[$i]} of b=${bv_num[$(($i+1))]}s/mm^2, high b-value found."
		tput sgr0 # change terminal color to default color
	elif [ ${bv_num[$(($i+1))]} -lt 65 ]; then
		echo "${bv_num[$i]} of b=${bv_num[$(($i+1))]}s/mm^2 (null image(s))"
		null[${null_tmp}]=${bv_num[$(($i+1))]}
		null_tmp=$((${null_tmp} + 1))
	else
		echo "${bv_num[$i]} of b=${bv_num[$(($i+1))]}s/mm^2"
		lowb[${lowb_tmp}]=${bv_num[$(($i+1))]}
		lowb_tmp=$((${lowb_tmp} + 1))
	fi
done

# Average DWI null images
if [ ${#null[*]} -eq 1 ]; then # only 1 group of null image
	nu=${null%.*}
	${mainS}/select_dwi_vols_st ${subjid}-preproc-unbiased.nii.gz ${subjid}-preproc.bval ${subjid}-preproc-Average_b0 ${nu} -m
elif [ ${#null[*]} -gt 1 ]; then # more than 1 group of null images
	tags=""
	for ((i=1; i<${#null[*]}; i++)); do
		tags="${tags} -b ${null[$i]}"
	done
	${mainS}/select_dwi_vols_st ${subjid}-preproc-unbiased.nii.gz ${subjid}-preproc.bval ${subjid}-preproc-Average_b0 ${null[0]} ${tags} -m
fi

# Extract DWI low-b images
if [ ${#lowb[*]} -eq 1 ]; then # only 1 group of low b-value
	b=${lowb%.*}
	${mainS}/select_dwi_vols_st ${subjid}-preproc-unbiased.nii.gz ${subjid}-preproc.bval ${subjid}-preproc-lowb-only-data ${b} -obv ${subjid}-preproc.bvec
elif [ ${#lowb[*]} -gt 1 ]; then # more than 1 group of low b-balues
	tags=""
	 for ((i=1; i<${#lowb[*]}; i++)); do
	 	tags="${tags} -b ${lowb[$i]}"
	 done
	 ${mainS}/select_dwi_vols_st ${subjid}-preproc-unbiased.nii.gz ${subjid}-preproc.bval ${subjid}-preproc-lowb-only-data ${lowb[0]} -obv ${subjid}-preproc.bvec ${tags}
fi

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