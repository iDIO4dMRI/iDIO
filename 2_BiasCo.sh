#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Alan Huang
## Version 1.0 /2020/02/05
##
## Edit: Options, 2020/04/07, Tsen
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

EOF
exit 1
}

# Setup default variables
OriDir=$(pwd)
Topup=0
# The text file for phase encoding direction labeling: 0 0 0 0 = AP PA LR RL
Phase_encoding=Index_PE.txt
run_script=y

args="$(sed -E 's/(-[A-Za-z]+ )([^-]*)( |$)/\1"\2"\3/g' <<< $@)"
declare -a a="($args)"
set - "${a[@]}"

arg=-1

# Parse options
while getopts "hd:P:" optionName; 
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

Phase_index=($(cat $OriDir/1_DWIprep/$Phase_encoding))
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
	File1=`ls *dwi.nii.gz`
else
	File1=`ls *${direction[0]}.nii.gz`
fi

DType=$(fslinfo $File1 | grep data_type | awk '{print $2}')
case $Topup in
	1 )
		echo only one dwi

		cp $(echo ${File1%.*.*}).nii.gz ${OriDir}/2_BiasCo
		cp $(echo ${File1%.*.*}).bval ${OriDir}/2_BiasCo
		cp $(echo ${File1%.*.*}).bvec ${OriDir}/2_BiasCo

		cd $OriDir/2_BiasCo
		
		dwidenoise -nthreads 2 $(echo ${File1%.*.*}).nii.gz Temp-denoise.nii.gz
		mrdegibbs -datatype $DType -nthreads 2 Temp-denoise.nii.gz $(echo ${File1%.*.*})-denoise-deGibbs.nii.gz
		;;
	3 )
		echo using merged dwi

		File2=`ls *${direction[1]}.nii.gz`
		fslmerge -a $(echo ${File1%.*.*})${direction[1]} $File1 $File2

		mv $(echo ${File1%.*.*})${direction[1]}.nii.gz $OriDir/2_BiasCo	

		bval1=$(cat $(echo ${File1%.*.*}).bval)
		bval2=$(cat $(echo ${File2%.*.*}).bval)
		echo $bval1 $bval2 > $OriDir/2_BiasCo/$(echo ${File1%.*.*})${direction[1]}.bval
		
# 		bvec1=$(cat $(echo ${File1%.*.*}).bvec)
# 		bvec2=$(cat $(echo ${File2%.*.*}).bvec)
#       paste -d "\0" ${File1%.*.*}.bvec ${File2%.*.*}.bvec > $OriDir/2_BiasCo/$(echo ${File1%.*.*})${direction[1]}.bvec
		paste -d " " ${File1%.*.*}.bvec ${File2%.*.*}.bvec > $OriDir/2_BiasCo/$(echo ${File1%.*.*})${direction[1]}.bvec
        
		cd $OriDir/2_BiasCo
		
		dwidenoise -nthreads 2 $(echo ${File1%.*.*})${direction[1]}.nii.gz Temp-denoise.nii.gz
		mrdegibbs -datatype $DType -nthreads 2 Temp-denoise.nii.gz $(echo ${File1%.*.*})${direction[1]}-denoise-deGibbs.nii.gz
		;;
esac

cd ${OriDir}/2_BiasCo
rm -f ./Temp-denoise.nii.gz
File_denoise=$(ls *-denoise-deGibbs.nii.gz | sed 's/.nii.gz//g')
File_bval=$(ls *.bval)

select_dwi_vols ${File_denoise}.nii.gz $File_bval temp 0 > b0_report.txt
B0num=$(echo $(cat b0_report.txt) | awk -F "--vols=" '/--vols=/{print $2}' | sed 's/,/ /g' | awk '{print NF}')

if [[ "${B0num}" -gt "3"  ]]; then
	echo "Calling Matlab for Drifting Correction"
	CMD="correct_signal_drift_1211('${File_denoise}.nii.gz', '${File_bval}', 0, 'piecewise', '${File_denoise}-DriftCo.nii.gz')"
	matlab -nodisplay -r "${CMD}; quit"
	mrconvert -datatype ${DType} -force ${File_denoise}-DriftCo.nii.gz ${File_denoise}-DriftCo.nii.gz
else
	echo "Not enough number of b0 (null scans), drifting correction skipped"
fi

