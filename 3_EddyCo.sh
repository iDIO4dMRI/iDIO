#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Shintai Chong
## Version 1.0 /2020/02/05
##
## Edit: 2020/04/20, Tsen, MBF location
## Edit: 2020/07/30, Tai, .json file detection for eddy input
## Edit: 2020/01/22, Tai, use eddy function for non-topup dwi
##						  add a zero image if number of z-dimension is odd (-zeropad)
##						  move biasco from step 4
##						  created [Preprocessed_data] folder for preprocessed data 
## Edit:2021/07/22, Heather, move resize step in the end
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage(){
	cat <<EOF

3_EddyCo - Distortion & eddy correction and bias filed correction for DWI dataset.
		    1_DWIprep and 2_BiasCo are needed before processing this script.
		    3_EddyCo and Preprocessed_data will be created

Usage:	3_EddyCo -[options]

System will automatically detect all folders in directory if no input arguments supplied

Options:
	-p 	Input directory; [default = pwd directory]
	-c 	Using CUDA to speed up. NVIDIA GPU with CUDA v9.1 or CUDA v8.0 is available to use this option.
	-m 	Slice-to-vol motion correction. This option is only implemented for the CUDA version.
	-r  rResize dwi image by .json text file with information about matrix size.
	-t  Input Bzero threshold; [default = 10];

EOF
exit 1
}

# Setup default variables
OriDir=$(pwd)
zeropad=0
MBF=sw
cuda_ver=0
mporder=0
rsimg=0
Bzerothr=10
run_script=y

args="$(sed -E 's/(-[A-Za-z]+ )([^-]*)( |$)/\1"\2"\3/g' <<< $@)"
declare -a a="($args)"
set - "${a[@]}"

arg=-1

# Parse options
while getopts "hp:cmrt:" optionName;
do
	#echo "-$optionName is present [$OPTARG]"
	case $optionName in
	h)
		Usage
		;;
	p)
		OriDir=$OPTARG
		;;
	c)
		#cuda_ver=$(nvcc --version | grep release | cut -d ' ' -f 5 | sed 's/,//g')
		cuda_ver=9.1
		;;
	m)
		mporder=1
		;;
	r)
		rsimg=1
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

# CUDA version
if [ -z ${cuda_ver} ]; then
	echo ""
	echo "CUDA version not found..."
	exit 1
fi

# Check if previous step was done
if [ ! -d "${OriDir}/2_BiasCo" ] || [ ! -d "${OriDir}/1_DWIprep" ]; then
	echo ""
	echo "Error: 1_DWIprep or 2_BiasCo are not detected."
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

# Multi-Band factor
if [ -f "${OriDir}/1_DWIprep/MBF.txt" ]; then
	MBF=both
else
	mporder=0
fi

# Topup=2 do topup
Phase_index=($(cat ${OriDir}/1_DWIprep/Index_PE.txt))
Topup=$((${Phase_index[0]} + ${Phase_index[1]} + ${Phase_index[2]} + ${Phase_index[3]}))

if [ -d ${OriDir}/3_EddyCo ]; then
	echo ""
	echo "3_EddyCo was detected,"
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

case ${Topup} in
	1) # Without Topup
		[ -d ${OriDir}/3_EddyCo ] || mkdir ${OriDir}/3_EddyCo
		cp ${OriDir}/2_BiasCo/${handle}.nii.gz ${OriDir}/3_EddyCo
		b_handle=$(basename -- $(find ${OriDir}/2_BiasCo -maxdepth 1 -name "*.bval*") | cut -f1 -d '.')
		cp ${OriDir}/2_BiasCo/${b_handle}.bval ${OriDir}/3_EddyCo
		cp ${OriDir}/2_BiasCo/${b_handle}.bvec ${OriDir}/3_EddyCo
		cp ${OriDir}/1_DWIprep/Acqparams_Topup.txt ${OriDir}/3_EddyCo
		cp ${OriDir}/1_DWIprep/Eddy_Index.txt ${OriDir}/3_EddyCo
		cd ${OriDir}/3_EddyCo
		bet ${handle}.nii.gz bet_Brain.nii.gz -m -f 0.2 -R
		json_DIR=(`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*dwi*.json*"`)
		if [ -f ${json_DIR} ]; then
			# with .json file
			j=1
			json_DIR=(`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*dwi*.json*"`)
			cp ${json_DIR} ${OriDir}/3_EddyCo/DWI.json
		else # without .json file
			j=0
		fi
		case ${cuda_ver} in
			0) # without cuda
				if [ ${j} == 0 ]; then # without .json file
					eddy --imain=${handle}.nii.gz --mask=bet_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --out=${handle}-EddyCo --verbose
				elif [ ${j} == 1 ]; then
					eddy --imain=${handle}.nii.gz --mask=bet_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF
				fi
				;;
			9.1) # cuda9.1
				if [ ${j} == 0 ]; then # without .json file
					eddy_cuda9.1 --imain=${handle}.nii.gz --mask=bet_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --out=${handle}-EddyCo --verbose
				elif [ ${j} == 1 ]; then
					if [ ${mporder} == 0 ]; then
						eddy_cuda9.1 --imain=${handle}.nii.gz --mask=bet_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF
					else # with --mporder 8
						eddy_cuda9.1 --imain=${handle}.nii.gz --mask=bet_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF --mporder=8
					fi
				fi
				;;
			8.0) # cuda8.0
				if [ ${j} == 0 ]; then # without .json file
					eddy_cuda8.0 --imain=${handle}.nii.gz --mask=bet_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --out=${handle}-EddyCo --verbose
				elif [ ${j} == 1 ]; then
					if [ ${mporder} == 0 ]; then
						eddy_cuda8.0 --imain=${handle}.nii.gz --mask=bet_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF
					else # with --mporder 8
						eddy_cuda8.0 --imain=${handle}.nii.gz --mask=bet_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF --mporder=8
					fi
				fi
				;;
		esac
		cp ${b_handle}.bval ${handle}-EddyCo.bval
		cp ${handle}-EddyCo.eddy_rotated_bvecs ${handle}-EddyCo.bvec
		rm ${b_handle}.bvec ${b_handle}.bval ${handle}-EddyCo.eddy_rotated_bvecs

		# Output QC
		eddy_quad ${handle}-EddyCo -idx Eddy_Index.txt -par Acqparams_Topup.txt -m bet_Brain_mask.nii.gz -b ${handle}-EddyCo.bval

		;;

	3) # With Topup
		[ -d ${OriDir}/3_EddyCo ] || mkdir ${OriDir}/3_EddyCo
		cp ${OriDir}/1_DWIprep/Acqparams_Topup.txt ${OriDir}/3_EddyCo
		cp ${OriDir}/1_DWIprep/Eddy_Index.txt ${OriDir}/3_EddyCo
		json_DIR=(`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*dwi*.json*"`)
		if [ -f ${json_DIR} ]; then
			# with .json file
			j=1
			json_DIR=(`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*dwi*.json*"`)
			cp ${json_DIR} ${OriDir}/3_EddyCo/DWI.json
		else # without .json file
			j=0
		fi
		cp ${OriDir}/2_BiasCo/${handle}.nii.gz ${OriDir}/3_EddyCo
		b_handle=$(basename -- $(find ${OriDir}/2_BiasCo -maxdepth 1 -name "*.bval*") | cut -f1 -d '.')
		cp ${OriDir}/2_BiasCo/${b_handle}.bval ${OriDir}/3_EddyCo
		cp ${OriDir}/2_BiasCo/${b_handle}.bvec ${OriDir}/3_EddyCo
		cd ${OriDir}/3_EddyCo

		# check dwi slice number
		dimz=$(fslinfo ${OriDir}/3_EddyCo/${handle}.nii.gz | awk 'NR==4{print $2}')
		if (( $dimz % 2 )); then
			zeropad=1
        	echo "The dwi data z-dimansion is $dimz"
        	echo "a zero slice will be added on the top of dwi"
        	mrgrid ${OriDir}/3_EddyCo/${handle}.nii.gz pad -all_axes -axis 2 0,1 ${OriDir}/3_EddyCo/${handle}-zeropad.nii.gz
        	handle_raw=${handle}
        	handle=${handle}-zeropad
    	fi

		# find the second B0 from Eddy_index.txt
		line=($(cat ${OriDir}/3_EddyCo/Eddy_Index.txt))
		sec_B0=0
		while [ ${line[$sec_B0]} == 1 ]; do
			sec_B0=$(($sec_B0+1))
		done

		fslroi ${handle}.nii.gz first_B0.nii.gz 0 1
		fslroi ${handle}.nii.gz second_B0.nii.gz $sec_B0 1
		fslmerge -t B0.nii.gz first_B0.nii.gz second_B0.nii.gz

		topup --imain=B0.nii.gz --datain=Acqparams_Topup.txt --config=b02b0.cnf --out=Topup_Output --fout=Field --iout=Unwarped_Images

		fslmaths Unwarped_Images.nii.gz -Tmean Mean_Unwarped_Images.nii.gz
		bet Mean_Unwarped_Images.nii.gz Mean_Unwarped_Images_Brain.nii.gz -m -f 0.2 -R

		case ${cuda_ver} in
			0) # without cuda
				if [ ${j} == 0 ]; then # without .json file
					eddy --imain=${handle}.nii.gz --mask=Mean_Unwarped_Images_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --topup=Topup_Output --out=${handle}-EddyCo --verbose
				elif [ ${j} == 1 ]; then
					eddy --imain=${handle}.nii.gz --mask=Mean_Unwarped_Images_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --topup=Topup_Output --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF
				fi
				;;
			9.1) # cuda9.1
				if [ ${j} == 0 ]; then # without .json file
					eddy_cuda9.1 --imain=${handle}.nii.gz --mask=Mean_Unwarped_Images_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --topup=Topup_Output --out=${handle}-EddyCo --verbose
				elif [ ${j} == 1 ]; then
					if [ ${mporder} == 0 ]; then
						eddy_cuda9.1 --imain=${handle}.nii.gz --mask=Mean_Unwarped_Images_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --topup=Topup_Output --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF
					else # with --mporder 8
						eddy_cuda9.1 --imain=${handle}.nii.gz --mask=Mean_Unwarped_Images_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --topup=Topup_Output --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF --mporder=8
					fi
				fi
				;;
			8.0) # cuda8.0
				if [ ${j} == 0 ]; then # without .json file
					eddy_cuda8.0 --imain=${handle}.nii.gz --mask=Mean_Unwarped_Images_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --topup=Topup_Output --out=${handle}-EddyCo --verbose
				elif [ ${j} == 1 ]; then
					if [ ${mporder} == 0 ]; then
						eddy_cuda8.0 --imain=${handle}.nii.gz --mask=Mean_Unwarped_Images_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --topup=Topup_Output --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF
					else # with --mporder 8
						eddy_cuda8.0 --imain=${handle}.nii.gz --mask=Mean_Unwarped_Images_Brain_mask.nii.gz --index=Eddy_Index.txt --bvals=${b_handle}.bval --bvecs=${b_handle}.bvec --acqp=Acqparams_Topup.txt --topup=Topup_Output --out=${handle}-EddyCo --json=DWI.json --verbose --data_is_shelled --ol_type=$MBF --mporder=8
					fi
				fi
				;;
		esac

		cp ${b_handle}.bval ${handle}-EddyCo.bval
		cp ${handle}-EddyCo.eddy_rotated_bvecs ${handle}-EddyCo.bvec
		rm ${b_handle}.bvec ${b_handle}.bval ${handle}-EddyCo.eddy_rotated_bvecs

		# Output QC
		eddy_quad ${handle}-EddyCo -idx Eddy_Index.txt -par Acqparams_Topup.txt -m Mean_Unwarped_Images_Brain_mask.nii.gz -b ${handle}-EddyCo.bval
		;;
esac

# Bias correct
dwibiascorrect ants ${OriDir}/3_EddyCo/${handle}-EddyCo.nii.gz ${OriDir}/3_EddyCo/${handle}-EddyCo-unbiased.nii.gz -fslgrad ${OriDir}/3_EddyCo/${handle}-EddyCo.bvec ${OriDir}/3_EddyCo/${handle}-EddyCo.bval -force

if [ ${zeropad} == 1 ]; then # Remove padding slice
	echo "remove padding slice..."
	mrgrid ${OriDir}/3_EddyCo/${handle}-EddyCo-unbiased.nii.gz pad -all_axes -axis 2 0,-1 ${OriDir}/3_EddyCo/${handle_raw}-EddyCo-unbiased.nii.gz
fi


[ -d ${OriDir}/Preprocessed_data ] || mkdir ${OriDir}/Preprocessed_data
cp ${OriDir}/3_EddyCo/${handle}-EddyCo-unbiased.nii.gz ${OriDir}/Preprocessed_data/dwi_preprocessed.nii.gz
cp ${OriDir}/3_EddyCo/${handle}-EddyCo.bval ${OriDir}/Preprocessed_data/dwi_preprocessed.bval
cp ${OriDir}/3_EddyCo/${handle}-EddyCo.bvec ${OriDir}/Preprocessed_data/dwi_preprocessed.bvec

json_file=(`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*dwi*.json*"`)
if [ -f ${json_file} ]; then
	cp ${json_file} ${OriDir}/Preprocessed_data/DWI.json
fi

# Check Resize
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

# Create Averaged B0 mask
dwiextract ${OriDir}/Preprocessed_data/${handle}.nii.gz - -fslgrad ${OriDir}/Preprocessed_data/${handle}.bvec ${OriDir}/Preprocessed_data/${handle}.bval -bzero -config BZeroThreshold ${Bzerothr} -quiet| mrmath - mean -axis 3 ${OriDir}/Preprocessed_data/${handle}-Average_b0.nii.gz -quiet
bet ${OriDir}/Preprocessed_data/${handle}-Average_b0.nii.gz ${OriDir}/3_EddyCo/${handle}-Average_b0-brain -f 0.2 -m
