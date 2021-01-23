#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Clementine Kung
## Version 1.1 2020/08/26
##########################################################################################################################
# 20200730 - Establish from DICOM using mrconvert
# 20200826 - Change to dcm2niix 
# 20210122 - change BIDSDir structure
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

mkdir -p ${BIDSDir}/anat
mkdir -p ${BIDSDir}/dwi

cd ${dcmDir}

all_folder=$(ls -d *)

for folder in ${all_folder}; do
	cd ${dcmDir}
	dw_scheme=$(mrinfo ${folder} -property dw_scheme)
	if [[ ! -z ${dw_scheme} ]]; then
		dcm2niix -z y -f dwi_${folder} -o ${BIDSDir}/dwi ${folder} 
	else
		dcm2niix -z y -f T1w -o ${BIDSDir}/anat ${folder} 
	fi
done