#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Clementine Kung
## Version 1.0 2021/10/11
##########################################################################################################################
# 20211011 - start scripting
##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage() {
    cat<<EOF
    
    dMRI processing  v1.0

    0_CheckData - Initial checking the data compatibility

    Usage: 0_CheckData -b <BIDSDir> 

EOF
    exit
}

BIDSDir=

while getopts "hb:v" OPTION; do
    case $OPTION in
    h) Usage;; 
    b) BIDSDir=$OPTARG;;
    v) verbose=1;;
    ?) Usage;;
    esac
done

if [ "${BIDSDir}" == "" ]; then
    Usage
fi

cd ${BIDSDir}
BIDSDir=${pwd}

mkdir -p ${BIDSDir}/tmp
cd ${BIDSDir}/tmp
/bin/cp -f ${BIDSDir}/dwi/*b0* . 2>>error.log
/bin/cp -f ${BIDSDir}/dwi/*dwi* . 2>>error.log
/bin/cp -f ${BIDSDir}/dwi/*DWI* . 2>>error.log

for DWI_file in *DWI*; do
	nname=$(echo ${DWI_file} | sed 's/DWI/dwi/g')
 	mv ${DWI_file} $nname . 2>>error.log
done

# compress
gzip *.nii 2>>error.log

# check fieldmap
n_b0=$(ls *b0*.nii.gz | wc -l)
n_dwi=$(ls *dwi*.nii.gz | wc -l)
n_dwi=$[${n_b0}+${n_dwi}]

if [ ${n_dwi} -eq "1" ] && [ -d "${BIDSDir}/fmap/" ]; then

	cd ${BIDSDir}/tmp
	dwi_file=($(ls *dwi*.nii.gz))
	dwi_file=${dwi_file[0]}
	dwi_dim=($(mrinfo -size ${dwi_file}))

	cd ${BIDSDir}/fmap/
	fmap_name_all=$(ls *)
	fmap_file=($(ls *.nii*))
	fmap_file=${fmap_file[0]}
	fmap_dim=($(mrinfo -size ${fmap_file}))

	if [ "${dwi_dim[0]}" -eq "${fmap_dim[0]}" ] && [ "${dwi_dim[2]}" -eq "${fmap_dim[2]}" ]; then
		cd ${BIDSDir}/tmp
		for fmap_name in ${fmap_name_all}; do
			/bin/cp -f ${BIDSDir}/fmap/${fmap_name} .
			mv ${fmap_name} dwi_${fmap_name}
		done
	fi
fi

gzip *.nii 2>>error.log
/bin/rm -f error.log

# read .json file
json_dir=$(ls -d ${BIDSDir}/tmp/*dwi*.json)
json_dir_tmp=(${json_dir})
n_json_file=$(ls -d ${BIDSDir}/tmp/*dwi*.json | wc -l)


# check if .json exist
if [ "${json_dir}" == "" ] || [ "${n_json_file}" -eq "0" ]; then

	cd ${PreprocDir}/1_DWIprep
	n_nifti_file=$(ls -d ${BIDSDir}/tmp/*dwi*.nii.gz | wc -l)

	if [[ ${n_json_file} -eq "0" ]]; then
	    echo ""
		echo "Error: 0_BIDS_NIFTI is empty."
		echo "Please check BIDS files..."
		exit 1
	fi
else

	## read .json file
	Rec=0
	for json_file in ${json_dir}; do

		Rec=$[$Rec+1]
		MultibandAccelerationFactor=0
		SeriesNumber=0

		filename=${json_file:0:${#json_file}-5}
		echo "====Check inforamtion for $(basename ${filename})===="
		while read line; do

			tmp=(${line})

			case ${tmp[0]} in
			'"PhaseEncodingDirection":' | '"PhaseEncodingAxis":')
				d=${tmp[1]}
				d_tmp=${d:1:${#d}-3}

				case "$d_tmp" in			
				"j")
					PED=PA
					PhaseEncodingDirectionCode[0]=${Rec}
					Acqparams_Topup_tmp="0 1 0" 
					;;
				"j-") 
					PED=AP
					PhaseEncodingDirectionCode[1]=${Rec}
					Acqparams_Topup_tmp="0 -1 0"
					;;
				"i") 
					PED=RL
					PhaseEncodingDirectionCode[2]=${Rec}
					Acqparams_Topup_tmp="1 0 0"
					;;
				"i-") 
					PED=LR
					PhaseEncodingDirectionCode[3]=${Rec}
					Acqparams_Topup_tmp="-1 0 0" 
					;;
				esac
			;;

			'"SeriesNumber":')
				d=${tmp[1]}
				SeriesNumber=${d:0:${#d}-1}
			;;

			'"Manufacturer":')
				d=${tmp[1]}
				Manufacturer=${d:0:${#d}-1}
			;;

			esac

		done < ${json_file}
	done
fi

# Manufacturer & PhaseEncodingDirection
DirectionCheck=0
PhaseEncodingDirectionCode_tmp=(${PhaseEncodingDirectionCode})
for i in {0..3}; do
	if [[ "${PhaseEncodingDirectionCode_tmp[$i]}" -eq "1" ]]; then
		DirectionCheck=1
	fi
done
if [ "${Rec}" -ge "2" ] && [ "${DirectionCheck}" -eq "0" ]; then

	case "${Manufacturer}" in
		Siemens) echo "Error: Two dwi data with same phase encoding direction."
            ;;
        GE) 
			echo "Warning: Two dwi data"
			echo "(1) with the same PhaseEncodingDirection"
			echo "(2) if not, needed to edit the info of PhaseEncodingDirection in json file j/j- (PA:j, AP:j-)"
            ;;
        Philips | UIH | UI) 
			echo "Warning: Two dwi data"
			echo "(1) with the same PhaseEncodingAxis"
			echo "(2) if not, needed to edit the info of PhaseEncodingAxis in json file j/j- (PA:j, AP:j-)"
            ;;
    esac
fi

# Series number
if [ "${SeriesNumber}" -eq "0" ]; then
	echo "Suggest to use 1_DWIprep with -first -second options"
fi

# remove tmp folder
/bin/rm -rf ${BIDSDir}/tmp