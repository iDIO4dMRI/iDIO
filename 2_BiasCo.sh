#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Alan Huang
## Version 1.0 /2020/02/05
##
## Edit: 2020/04/07, Tsen, Options
## Edit: 2020/04/20, Tsen, Options
## Edit: 2021/02/18, Heather, (1) python, (2) dwicat, (3) replace dwi_select_vol with mrinfo and bvalue threshold
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage(){
	cat <<EOF

2_BiasCo - Gibbs ringing correction, 4-D signal denoise, and signal drifting correction
		 1_DWIprep is needed before processing this script.
		 2_BiasCo will be created

Usage:	2_BiasCo -[options]

System will automatically detect all folders in directory if no input arguments supplied

Options:
	-p 	Input directory; [default = pwd directory]
	-t  Input Bzero threshold; [default = 10]; 
EOF
exit 1
}

args="$(sed -E 's/(-[A-Za-z]+ )([^-]*)( |$)/\1"\2"\3/g' <<< $@)"
declare -a a="($args)"
set - "${a[@]}"
arg=-1

# Setup default variables
OriDir=$(pwd)
Bzerothr=10

# Parse options
while getopts "hp:t:" optionName;
do
	#echo "-$optionName is present [$OPTARG]"
	case $optionName in
	h)
		Usage;;
	p)
		OriDir=$OPTARG;;
	t)
		Bzerothr=$OPTARG
		;;
	\?)
		exit 42;;
	*)
	  echo "Unrecognised option $1" 1>&2
	  exit 1
		;;
	esac
done

# The text file for phase encoding direction labeling: 0 0 0 0 = PA AP RL LR
Phase_index=($(cat $OriDir/1_DWIprep/Index_PE.txt))
Topup=$((${Phase_index[0]} + ${Phase_index[1]} + ${Phase_index[2]} + ${Phase_index[3]}))

PE=($(echo PA AP RL LR))
for Order in 0 1 2 3; do
	if [ ${Phase_index[${Order}]} == "1" ]; then
    direction[0]=${PE[${Order}]}
	fi
	if [ ${Phase_index[${Order}]} == "2" ]; then
    direction[1]=${PE[${Order}]}
	fi
done

# Check if previous step was done
if [ ! -d "${OriDir}/1_DWIprep" ]; then
	echo ""
	echo "Error: 1_DWIprep not detected."
	echo "Please process previous step..."
	exit 1
fi

run_script=y
if [ -d ${OriDir}/2_BiasCo ]; then
	echo ""
	echo "2_BiasCo detected,"
	echo "press y or wait for 10 seconds to continue,"
	echo "press n to terminate the program..."
	read -t 10 -p "y/n : " run_script
	if [ -z "$run_script" ]; then
		run_script=y
	fi
fi

if [ ${run_script} == "n" ]; then
	echo "System terminated"
	exit 1
fi
if [ ${run_script} != "y" ]; then
	echo ""
	echo "Error: Input is not valid..."
	exit 1
fi

[ -d ${OriDir}/2_BiasCo ] || mkdir ${OriDir}/2_BiasCo
cd ${OriDir}/0_BIDS_NIFTI

if [[ ${#direction[@]} == 1 ]]; then
	File1=`ls *dwi*.nii.gz`
else
	File1=`ls *${direction[0]}.nii.gz`
fi

case $Topup in
	1 )
		echo Input DWIs contain only one PE direction

		cp $(echo ${File1%.*.*}).nii.gz ${OriDir}/2_BiasCo
		cp $(echo ${File1%.*.*}).bval ${OriDir}/2_BiasCo
		cp $(echo ${File1%.*.*}).bvec ${OriDir}/2_BiasCo

		cd $OriDir/2_BiasCo

		dwidenoise $(echo ${File1%.*.*}).nii.gz Temp-denoise.nii.gz
		mrdegibbs Temp-denoise.nii.gz $(echo ${File1%.*.*})-denoise-deGibbs.nii.gz #Keep the data format output from mrdegibbs
		;;
	3 )
		echo Input DWIs contain more than one PE directions

		File2=`ls *${direction[1]}.nii.gz`
		fslmerge -a $(echo ${File1%.*.*})${direction[1]} $File1 $File2

		mv $(echo ${File1%.*.*})${direction[1]}.nii.gz $OriDir/2_BiasCo

		bval1=$(cat $(echo ${File1%.*.*}).bval)
		bval2=$(cat $(echo ${File2%.*.*}).bval)
		echo $bval1 $bval2 > $OriDir/2_BiasCo/$(echo ${File1%.*.*})${direction[1]}.bval

		paste -d " " ${File1%.*.*}.bvec ${File2%.*.*}.bvec > $OriDir/2_BiasCo/$(echo ${File1%.*.*})${direction[1]}.bvec

		cd $OriDir/2_BiasCo

		dwidenoise $(echo ${File1%.*.*})${direction[1]}.nii.gz Temp-denoise.nii.gz
		mrdegibbs Temp-denoise.nii.gz $(echo ${File1%.*.*})${direction[1]}-denoise-deGibbs.nii.gz #Keep the data format output from mrdegibbs
		;;
esac

cd ${OriDir}/2_BiasCo
rm -f ./Temp-denoise.nii.gz
File_denoise=$(ls *-denoise-deGibbs.nii.gz | sed 's/.nii.gz//g')
File_bval=$(ls *.bval)
File_bvec=$(ls *.bvec)

#
B0num=$(mrinfo ${File_denoise}.nii.gz -fslgrad ${File_bvec} ${File_bval}  -shell_sizes -config BZeroThreshold ${Bzerothr}|awk '{print $1}')

B0index=$(mrinfo ${File_denoise}.nii.gz -fslgrad dwi_APPA.bvec dwi_APPA.bval  -shell_indices -config BZeroThreshold ${Bzerothr}|awk {'print $1'})

#B0num > 3 -> do drift correction
if [[ "${B0num}" -gt "3"  ]]; then
	echo "Calling python script for Drifting Correction"
	python3 ${HOGIO}/python/driftco.py ${OriDir}/2_BiasCo/${File_denoise}.nii.gz ${B0index} ${OriDir}/2_BiasCo/${File_denoise}-DriftCo.nii.gz
else
	echo "Not enough number of b0 (null scans), drifting correction skipped"
fi
