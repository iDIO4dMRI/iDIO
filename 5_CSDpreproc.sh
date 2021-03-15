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

5_CSDpreproc - CSD preprocessing via MRtrix with Dhollanders algorithm.
			   b < Bzero threshold will be considered to null images [default = 10].
		       4_DTIFIT are needed before processing this script.
		       5_CSDpreproc will be created

Usage:	5_CSDpreproc -[options] 

System will automatically detect all folders in directory if no input arguments supplied

Options:
	-p 	Input directory; [default = pwd directory]
	-t  Input Bzero threhold; [default = 10];
	-r  rResize dwi image by .json text file with information about matrix size.

EOF
exit 1
}

# Setup default variables
OriDir=$(pwd)
Bzerothr=10
run_script=y
rsimg=0
args="$(sed -E 's/(-[A-Za-z]+ )([^-]*)( |$)/\1"\2"\3/g' <<< $@)"
declare -a a="($args)"
set - "${a[@]}"

arg=-1

# Parse options
while getopts "hp:t:r" optionName; 
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
	r)
		rsimg=1
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

if [ ! -d "${OriDir}/4_DTIFIT" ]; then
	echo ""
	echo "Error: 4_DTIFIT is not detected."
	echo "Please process previous step..."
	exit 1
fi


# if [ -f "`find ${OriDir}/Preprocessed_data -maxdepth 1 -name "dwi_preprocessed.nii.gz"`" ]; then
# 	handle=$(basename -- $(find ${OriDir}/Preprocessed_data -maxdepth 1 -name "dwi_preprocessed.nii.gz") | cut -f1 -d '.')
# else
# 	echo ""
# 	echo "No Preprocessed DWI image found..."
# 	exit 1
# fi

# if [ ! -f "`find ${OriDir}/Preprocessed_data -maxdepth 1 -name "dwi_preprocessed.bval"`" ] || [ ! -f "`find ${OriDir}/Preprocessed_data -maxdepth 1 -name "dwi_preprocessed.bvec"`" ]; then
# 	echo ""
# 	echo "No bvals/bvecs image found..."
# 	exit 1
# fi


if [ -f "`find ${OriDir}/4_DTIFIT -maxdepth 1 -name "*Average_b0.nii.gz"`" ]; then
	handleB0=${OriDir}/4_DTIFIT/*Average_b0.nii.gz
	handleMask=${OriDir}/4_DTIFIT/*b0-brain_mask.nii.gz
else
	echo ""
	echo "No Preprocessed AveragedB0 image found..."
	exit 1
fi

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

# # Check if DWI exists 
if [[ ${rsimg} -eq "1" ]]; then
	handle=dwi_preprocessed_resized
	if [[ -f ${OriDir}/Preprocessed_data/${handle}.nii.gz ]] && [[ -f ${OriDir}/Preprocessed_data/${handle}.bval ]] && [[ -f ${OriDir}/Preprocessed_data/${handle}.bvec ]]; then
		:
	elif [[ ! -f ${OriDir}/Preprocessed_data/${handle}.nii.gz ]] && [[ -f ${OriDir}/Preprocessed_data/dwi_preprocessed.nii.gz ]] ; then
		if [[ ! -f ${OriDir}/Preprocessed_data/DWI.json ]]; then
			echo "No .json text file found..."
			echo "use dwi_preprocessed.nii.gz"
			handle=dwi_preprocessed			
		else
			json_file=${OriDir}/Preprocessed_data/DWI.json
			while read line; do
				tmp=(${line})
				case ${tmp[0]} in
					'"AcquisitionMatrixPE":')
						d=${tmp[1]}
						AcquisitionMatrixPE=${d:0:${#d}-1}				
					;;
				esac
			done < $json_file

			g=($(fslinfo ${OriDir}/Preprocessed_data/dwi_preprocessed.nii.gz | grep -i dim))	
			dim1=${g[1]}; dim2=${g[3]};	dim3=${g[5]}
			echo dim1,2: ${AcquisitionMatrixPE}
			echo dim3: ${dim3}
			if [[ "$dim1" != "${AcquisitionMatrixPE}" ]] || [[ "$dim2" != "${AcquisitionMatrixPE}" ]]; then		
				echo "mrgridmrgridmrgridmrgridmrgrid"
				mrgrid ${OriDir}/Preprocessed_data/dwi_preprocessed.nii.gz regrid ${OriDir}/Preprocessed_data/${handle}.nii.gz -size ${AcquisitionMatrixPE},${AcquisitionMatrixPE},${dim3}		
				cp ${OriDir}/Preprocessed_data/dwi_preprocessed.bval ${OriDir}/Preprocessed_data/${handle}.bval
				cp ${OriDir}/Preprocessed_data/dwi_preprocessed.bvec ${OriDir}/Preprocessed_data/${handle}.bvec
			else
				handle=dwi_preprocessed
			fi
		fi
	else
		echo ""
		echo "No dwi image found..."
		exit 1
	fi	
else
	if [ -f "`find ${OriDir}/Preprocessed_data -maxdepth 1 -name "dwi_preprocessed.nii.gz"`" ]; then
		handle=$(basename -- $(find ${OriDir}/Preprocessed_data -maxdepth 1 -name "dwi_preprocessed.nii.gz") | cut -f1 -d '.')
	else
		echo ""
		echo "No dwi image found..."
		exit 1
	fi		
fi


[ -d ${OriDir}/5_CSDpreproc ] || mkdir ${OriDir}/5_CSDpreproc

# S1 CSDproproc

# copy data
cp ${OriDir}/Preprocessed_data/${handle}.nii.gz ${OriDir}/5_CSDpreproc/
cp ${OriDir}/Preprocessed_data/${handle}.bvec ${OriDir}/5_CSDpreproc/
cp ${OriDir}/Preprocessed_data/${handle}.bval ${OriDir}/5_CSDpreproc/
mkdir ${OriDir}/5_CSDpreproc/S1_Response

cd ${OriDir}/5_CSDpreproc/
# convert into MRtrix format
mrconvert ${handle}.nii.gz ${OriDir}/5_CSDpreproc/${handle}.mif -fslgrad ${OriDir}/5_CSDpreproc/${handle}.bvec ${OriDir}/5_CSDpreproc/${handle}.bval 

#erode FSL Bet mask - which will generate in step4
maskfilter ${handleMask} erode ${OriDir}/5_CSDpreproc/${handle}-mask-erode.mif -npass 2 #this setting seems to be okay

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

	dwi2response dhollander ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S1_Response/response_wm.txt ${OriDir}/5_CSDpreproc/S1_Response/response_gm.txt ${OriDir}/5_CSDpreproc/S1_Response/response_csf.txt -config BZeroThreshold ${Bzerothr}

	if [[ ${shell_num_all} -eq 2 && ${hb} -eq 0 ]]; then
		echo "lack of high b-value (may cause poor angular resolution)"
	
		# for single-shell, 2 tissue
		dwi2fod msmt_csd ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S1_Response/response_wm.txt ${OriDir}/5_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S1_Response/response_csf.txt ${OriDir}/5_CSDpreproc/S1_Response/odf_csf.mif -mask ${handleMask} -config BZeroThreshold ${Bzerothr}

		# multi-tissue informed log-domain intensity normalisation
		mtnormalise ${OriDir}/5_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/5_CSDpreproc/S1_Response/odf_csf.mif ${OriDir}/5_CSDpreproc/S1_Response/odf_csf_norm.mif -mask ${OriDir}/5_CSDpreproc/${handle}-mask-erode.mif

	else	
		#for multi-shell

		dwi2fod msmt_csd ${OriDir}/5_CSDpreproc/${handle}.mif ${OriDir}/5_CSDpreproc/S1_Response/response_wm.txt ${OriDir}/5_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S1_Response/response_gm.txt ${OriDir}/5_CSDpreproc/S1_Response/odf_gm.mif ${OriDir}/5_CSDpreproc/S1_Response/response_csf.txt ${OriDir}/5_CSDpreproc/S1_Response/odf_csf.mif -mask ${handleMask} -config BZeroThreshold ${Bzerothr}

		# multi-tissue informed log-domain intensity normalisation
		mtnormalise ${OriDir}/5_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/5_CSDpreproc/S1_Response/odf_gm.mif ${OriDir}/5_CSDpreproc/S1_Response/odf_gm_norm.mif ${OriDir}/5_CSDpreproc/S1_Response/odf_csf.mif ${OriDir}/5_CSDpreproc/S1_Response/odf_csf_norm.mif -mask ${OriDir}/5_CSDpreproc/${handle}-mask-erode.mif
	fi 

else
	echo " Error: Input is not valid..."
	exit 1
fi
