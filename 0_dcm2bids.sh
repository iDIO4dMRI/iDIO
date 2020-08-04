#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Clementine Kung
## Version 1.0 2020/07/30
##########################################################################################################################
# 20200730 - Establish from DICOM 
##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage() {
    cat<<EOF
    
    dicom to bids  v1.0

    0_dcm2bids - DWI data preperation for the following processing

    Usage: 0_dcm2bids -d <dcmDir> -b <BIDSDir>

EOF
    exit
}

SubjName=
dcmDir=
BIDSDir=

while getopts "hs:d:b:v" OPTION
do
    case $OPTION in
    h)  
        Usage
        ;; 
    d)
        dcmDir=$OPTARG
        ;;
    b)
        BIDSDir=$OPTARG
        ;;
    v)
        verbose=1
        ;;
    ?)
        Usage
        ;;
    esac
done

if [ "${dcmDir}" == "" ] || [ "${BIDSDir}" == "" ]; then
    Usage
fi

mkdir -p ${BIDSDir}/0_BIDS/anat
mkdir -p ${BIDSDir}/0_BIDS/dwi

cd ${dcmDir}

all_folder=$(ls -d *)

for folder in ${all_folder}; do
	cd ${dcmDir}
	dw_scheme=$(mrinfo ${folder} -property dw_scheme)
	PD=$(mrinfo ${folder} -property PhaseEncodingDirection)
	if [[ ! -z ${dw_scheme} ]]; then

		case "${PD}" in			
			"j")
				PED=PA
				;;
			"j-") 
				PED=AP
				;;
			"i") 
				PED=RL
				;;
			"i-") 
				PED=LR
				;;
			esac
		mrconvert ${folder} dwi_${PED}.nii.gz -json_export dwi_${PED}.json -export_grad_fsl dwi_${PED}.bvec dwi_${PED}.bval
		/bin/mv dwi_${PED}.* ${BIDSDir}/0_BIDS/dwi
	else
		mrconvert ${folder} T1w.nii.gz -json_export T1w.json
		/bin/mv T1w.* ${BIDSDir}/0_BIDS/anat
	fi
done