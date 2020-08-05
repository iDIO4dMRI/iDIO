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

Usage(){

cat<<EOF
    
  dMRI processing pipeline v1.0

    0_dcm2bids: Convert DICOM DWI data to BIDS format used in the subsequent processing scripts.
                (The script assumes that the input directory contains *only* DWIs and anatomical DICOM data.)

    Usage: 0_dcm2bids -d <dcm_in> -b <bids_out>

EOF
    exit
}

while getopts ":d:b:h:" OPTION ; do
  case $OPTION in
    d)
      dcm_in=$OPTARG;;
    b)
      bids_out=$OPTARG;;
    h)  
      Usage;; 
    ?)
      Usage;;
  esac
done


# sanity checks
if [ "${dcm_in}" == "" ] || [ "${bids_out}" == "" ]; then
  Usage
fi
if [ ! -d "${dcm_in}" ] ; then
  echo "[ERROR] Input DICOM directory does not exist."
  exit
fi


# convert dicom to json
mkdir -p ${bids_out}/0_BIDS/anat ${bids_out}/0_BIDS/dwi
cd ${dcm_in}

all_folder=$(ls -d *)
for folder in ${all_folder}; do
	dw_scheme=$(mrinfo ${folder} -property dw_scheme)
	pe_dir=$(mrinfo ${folder} -property PhaseEncodingDirection)

	if [[ ! -z ${dw_scheme} ]]; then
		case "${pe_dir}" in			
			"j")
				PED=PA;;
			"j-") 
				PED=AP;;
			"i") 
				PED=RL;;
			"i-") 
				PED=LR;;
    esac
		mrconvert ${folder} dwi_${PED}.nii.gz -json_export dwi_${PED}.json -export_grad_fsl dwi_${PED}.bvec dwi_${PED}.bval
		mv dwi_${PED}.* ${bids_out}/0_BIDS/dwi
	else
		mrconvert ${folder} T1w.nii.gz -json_export T1w.json
		mv T1w.* ${bids_out}/0_BIDS/anat
	fi

done

