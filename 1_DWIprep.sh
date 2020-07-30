#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Clementine Kung
## Version 1.2 2020/05/26
##########################################################################################################################
# 20200424 - check dwi.bval dwi.bvec exist
# 20200429 - fixing imaging resize floating number problem
# 20200526 - mrgird (line 264), rename PED (line 271)
##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage() {
    cat<<EOF
    
    dMRI processing  v1.0

    1_DWIprep - DWI data preperation for the following processing

    Usage: 1_DWIprep -b <BIDSDir> -p <SubjectDir>

EOF
    exit
}

SubjName=
BIDSDir=
SubjectDir=

while getopts "hs:b:p:v" OPTION
do
    case $OPTION in
    h)  
        Usage
        ;; 
    b)
        BIDSDir=$OPTARG
        ;;
    p)
        SubjectDir=$OPTARG
        ;;
    v)
        verbose=1
        ;;
    ?)
        Usage
        ;;
    esac
done

if [ "${SubjectDir}" == "" ] || [ "${BIDSDir}" == "" ]; then
    Usage
fi

mkdir -p ${SubjectDir}/0_BIDS_NIFTI
cd ${SubjectDir}/0_BIDS_NIFTI
/bin/cp -f ${BIDSDir}/dwi/*dwi* .
/bin/cp -f ${BIDSDir}/dwi/*DWI* .
/bin/cp -f ${BIDSDir}/anat/*T1* .

# check filenames
for DWI_file in *DWI*; do
	nname=$(echo ${DWI_file} | sed 's/DWI/dwi/g')
 	mv ${DWI_file} $nname
done

for bvals_file in *.bvals; do
	mv ${bvals_file} ${bvals_file:0:${#bvals_file}-1}
done

for bvecs_file in *.bvecs; do
	mv ${bvecs_file} ${bvecs_file:0:${#bvecs_file}-1}
done

# prerename
for dwi_files in *dwi*; do
	mv ${dwi_files} prerename_${dwi_files}
done

# check dwi.bval dwi.bvec exist
for nifti_file in prerename_*dwi*.nii.gz; do
	dwi_filename=$(basename -- ${nifti_file} | cut -f1 -d '.')
	if [ ! -f "${dwi_filename}.bval" ]; then
		b="0"
		dim=($(fslhd ${dwi_filename}.nii.gz | cat -v | egrep 'dim4'))
    	for (( i=2; i <= ${dim[1]}; i++ )); do
		    b="$b 0"
      	done
    		echo $b >> ${dwi_filename}.bval
      	for (( i=1; i<=3; i++ )); do
      		echo $b >> ${dwi_filename}.bvec
      	done
	fi
done

# read .json file
json_dir=$(ls -d ${SubjectDir}/0_BIDS_NIFTI/prerename_*dwi*.json)
json_dir_tmp=(${json_dir})
n_json_file=$(ls -d ${SubjectDir}/0_BIDS_NIFTI/prerename_*dwi*.json | wc -l)

if [ "${json_dir}" == "" ] || [ "${n_json_file}" == "0" ]; then
    echo ""
	echo "Error: 0_BIDS_NIFTI is empty."
	echo "Please check BIDS files..."
	exit 1
fi

mkdir -p ${SubjectDir}/1_DWIprep
cd ${SubjectDir}/1_DWIprep

#echo ${json_dir}

/bin/rm -f Index_*.txt
/bin/rm -f Acqparams_Topup.txt
/bin/rm -f EddyIndex.txt
PhaseEncodingDirectionCode=(0 0 0 0)
Rec=0

sn=(0 0)
if [[ ${n_json_file} -gt 1 ]]; then
	
	for n in {1..2}; do
		n_tmp=$[${n}-1]
		while read line; do

			tmp=(${line})
			if [[ ${tmp[0]} == \"SeriesNumber\": ]]; then
				d=${tmp[1]}

				sn_tmp=${d:0:${#d}-1}	
				sn[${n_tmp}]=${sn_tmp}
			fi 
		done < ${json_dir_tmp[${n_tmp}]}
	done

	if [[ ${sn[0]} -gt ${sn[1]} ]]; then
		json_dir=$(echo ${json_dir_tmp[1]} ${json_dir_tmp[0]})
	fi
fi

## read .json file
for json_file in ${json_dir}; do

	cd ${SubjectDir}/1_DWIprep

	Rec=$[$Rec+1]
	MultibandAccelerationFactor=0

	prerename_filename=${json_file:0:${#json_file}-5}
	echo "\n====Check inforamtion for $(basename ${prerename_filename})===="

	while read line; do

		tmp=(${line})

		case ${tmp[0]} in
		'"PhaseEncodingDirection":' | '"PhaseEncodingAxis":')
			d=${tmp[1]}
			d_tmp=${d:1:${#d}-3}

			case "$d_tmp" in			
			"j")
				PED=PA
				PED_PA=PA
				PhaseEncodingDirectionCode[0]=${Rec}
				Acqparams_Topup_tmp="0 1 0" 
				;;
			"j-") 
				PED=AP
				PED_AP=AP
				PhaseEncodingDirectionCode[1]=${Rec}
				Acqparams_Topup_tmp="0 -1 0"
				;;
			"i") 
				PED=RL
				PED_RL=RL
				PhaseEncodingDirectionCode[2]=${Rec}
				Acqparams_Topup_tmp="1 0 0"
				;;
			"i-") 
				PED=LR
				PED_LR=LR
				PhaseEncodingDirectionCode[3]=${Rec}
				Acqparams_Topup_tmp="-1 0 0" 
				;;
			esac
			echo "PED: ${PED}"
		;;

		'"EffectiveEchoSpacing":')
			d=${tmp[1]}
			EffectiveEchoSpacing=${d:0:${#d}-1}	
			echo "EffectiveEchoSpacing: $EffectiveEchoSpacing"
		;;

		'"AcquisitionMatrixPE":')
			d=${tmp[1]}
			AcquisitionMatrixPE=${d:0:${#d}-1}
			EPIfactor=${AcquisitionMatrixPE}
			echo "AcquisitionMatrixPE: $AcquisitionMatrixPE"
		;;

		'"ReconMatrixPE":')
			d=${tmp[1]}
			ReconMatrixPE=${d:0:${#d}-1}
			echo "ReconMatrixPE: $ReconMatrixPE"
		;;

		'"MultibandAccelerationFactor":') 
			d=${tmp[1]}
			MultibandAccelerationFactor=${d:0:${#d}-1}			
			echo "MultibandAccelerationFactor: $MultibandAccelerationFactor" 
		;;

		'"SliceThickness":') 
			d=${tmp[1]}
			SliceThickness=${d:0:${#d}-1}			
			echo "SliceThickness: $SliceThickness" 
		;;
		esac

	done < ${json_file}

	## Acqparams_Topup.txt
	if [ "$MultibandAccelerationFactor" != 0 ]; then
		EchoSpacing=$(echo ${EffectiveEchoSpacing}*${MultibandAccelerationFactor} | bc)
		echo "EchoSpacing: ${EchoSpacing}"
		echo ${MultibandAccelerationFactor} > MBF.txt
	else
		EchoSpacing=${EffectiveEchoSpacing}
		echo "EchoSpacing: ${EffectiveEchoSpacing}"
	fi
	echo "EPIfactor: ${EPIfactor}"
	C4=$(echo ${EchoSpacing}*${EPIfactor} | bc)
	echo "C4: ${C4}"

	echo "${Acqparams_Topup_tmp} ${C4}" >> Acqparams_Topup.txt

	## read .bval file
	nn=$(cat ${prerename_filename}.bval)
	for n in ${nn}; do
		echo $Rec >> Eddy_Index.txt
	done

	## resize
	# Interpolation=$(echo "${ReconMatrixPE}/${AcquisitionMatrixPE}" | bc -l)
	# Interpolation=$((${ReconMatrixPE}/${AcquisitionMatrixPE}))
	if [ $(echo "${ReconMatrixPE} < ${AcquisitionMatrixPE}"|bc) -eq 1 ]; then
		mkdir -p ${SubjectDir}/0_BIDS_NIFTI/Preresize
		resizefile=$(basename ${prerename_filename}.nii.gz)
		mv ${prerename_filename}.nii.gz ${SubjectDir}/0_BIDS_NIFTI/Preresize
		cd ${SubjectDir}/0_BIDS_NIFTI/Preresize
		fslinfo ${resizefile} > fslinfo.txt

		g=($(grep -i dim3 fslinfo.txt))
		dim3=${g[1]}

		cd ${SubjectDir}/0_BIDS_NIFTI
		echo dim1,2: ${AcquisitionMatrixPE}
		echo dim3: ${dim3}
		#mrresize ./Preresize/${resizefile} ./${resizefile} -size ${AcquisitionMatrixPE},${AcquisitionMatrixPE},${dim3}
		mrgrid ./Preresize/${resizefile} regrid ./${resizefile} -size ${AcquisitionMatrixPE},${AcquisitionMatrixPE},${dim3}

		cd ${SubjectDir}/0_BIDS_NIFTI/Preresize
		mv ${resizefile} dwi_${PED}.nii.gz
	fi

	cd ${SubjectDir}/0_BIDS_NIFTI
	for file_format in nii.gz json bval bvec; do
		mv ${prerename_filename}.${file_format} dwi_${PED}.${file_format}
	done
	echo "filename change from $(basename ${prerename_filename}) to dwi_${PED}"

done

cd ${SubjectDir}/1_DWIprep

## Index_*.txt
PED_all=${PED_PA}${PED_AP}${PED_RL}${PED_LR}
echo "PhaseEncodingDirection: ${PED_all}"
echo "${PhaseEncodingDirectionCode[0]} ${PhaseEncodingDirectionCode[1]} ${PhaseEncodingDirectionCode[2]} ${PhaseEncodingDirectionCode[3]}" > Index_PE.txt
DirectionNumner=$[${PhaseEncodingDirectionCode[0]}+${PhaseEncodingDirectionCode[1]}+${PhaseEncodingDirectionCode[2]}+${PhaseEncodingDirectionCode[3]}]

## transform EddyIndex.txt
EddyIndex=$(cat Eddy_Index.txt)
echo $EddyIndex > Eddy_Index.txt

## check files
if [ $DirectionNumner -eq 1 ]; then
	/bin/rm -f Acqparams_Topup.txt
	/bin/rm -f Eddy_Index.txt
fi