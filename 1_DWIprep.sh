#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Clementine Kung
## Version 1.3.1 2020/12/29
##########################################################################################################################
# 20200424 - check dwi.bval dwi.bvec exist
# 20200429 - fixing imaging resize floating number problem
# 20200526 - mrgird, rename PED
# 20200730 - no .json, fix bug of mrgird
# 20200826 - check C4 from mrconvert and add mrconvert function (use mrconvert)
# 20210122 - fmap, 1 phase encoding direction
# 20210821 - total readout time
# 20210929 - TE bugfix
# 20211011 - add 1st & 2nd scan options, fieldmap bugfix
# 20220111 - change mv to rename
##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage() {
    cat<<EOF
    
    dMRI processing  v1.0

    1_DWIprep - DWI data preperation for the following processing

    Usage: 1_DWIprep -b <BIDSDir> -p <PreprocDir> 

    Options:
    -first	<first scan filename> 	If your json file have no "SeriesNumber" tag, 
    								please indicate the filename of the 1st scan <filename>.nii.gz e.g. dwi_PA
    -second	<second scan filename>	2nd scan <filename>.nii.gz ex. dwi_AP

EOF
    exit
}

BIDSDir=
PreprocDir=
FirstScan=
SecondScan=

while [ "$#" -gt 0 ]; do
    case "$1" in
    -b)			BIDSDir="$2"; shift; shift;;
    -p)			PreprocDir="$2"; shift; shift;;
	-first)		FirstScan="$2"; shift; shift;;
	-second)	SecondScan="$2"; shift; shift;;
    -h) Usage;;

    *) echo "unknown option:" "$1"; exit 1;;
    esac
done

if [ "${PreprocDir}" == "" ] || [ "${BIDSDir}" == "" ]; then
    Usage
fi

OrigDir=$(pwd)
cd ${OrigDir}
cd ${BIDSDir}
BIDSDir=$(pwd)
cd ${OrigDir}
cd ${PreprocDir}
PreprocDir=$(pwd)

mkdir -p ${PreprocDir}/0_BIDS_NIFTI
cd ${PreprocDir}/0_BIDS_NIFTI
/bin/cp -f ${BIDSDir}/dwi/*b0* . 2>>error.log
/bin/cp -f ${BIDSDir}/dwi/*dwi* . 2>>error.log
/bin/cp -f ${BIDSDir}/dwi/*DWI* . 2>>error.log
/bin/cp -f ${BIDSDir}/anat/*t1* . 2>>error.log
/bin/cp -f ${BIDSDir}/anat/*T1* . 2>>error.log

# compress
gzip *.nii 2>>error.log

# data order
cd ${PreprocDir}/0_BIDS_NIFTI
if [ "${FirstScan}" != "" ] && [ "${SecondScan}" != "" ]; then 
	
	Scan=0
	for dwi_files in ${FirstScan} ${SecondScan}; do
		Scan=$[$Scan+1]

		for file_type in nii.gz json bvec bval bvecs bvals; do
			[ ! -f "${dwi_files}.${file_type}" ] || mv ${dwi_files}.${file_type} dwi${Scan}.${file_type}
		done
	done
	#rename s/${FirstScan}/dwi1/g *
	#rename s/${SecondScan}/dwi2/g *
fi

# check filenames
for T1_file in *T1*.nii.gz; do
	[ ! -f "${T1_file}" ] || mv ${T1_file} T1w.nii.gz
done

for T1_file in *T1*.json; do
	[ ! -f "${T1_file}" ] || mv ${T1_file} T1w.json
done

for T1_file in *t1*.nii.gz; do
	[ ! -f "${T1_file}" ] || mv ${T1_file} T1w.nii.gz
done

for T1_file in *t1*.json; do
	[ ! -f "${T1_file}" ] || mv ${T1_file} T1w.json
done

for DWI_file in *DWI*; do
	nname=$(echo ${DWI_file} | sed 's/DWI/dwi/g')
	[ ! -f "${DWI_file}" ] || mv ${DWI_file} $nname
done

for b0_file in *b0*; do
	nname=$(echo ${b0_file} | sed 's/b0/dwi_b0/g')
	[ ! -f "${b0_file}" ] || mv ${b0_file} $nname
done

bvals_tmp=$(ls -f *.bvals 2>>error.log) 
for bvals_file in ${bvals_tmp}; do
	mv ${bvals_file} ${bvals_file:0:${#bvals_file}-1}
done

bvecs_tmp=$(ls -f *.bvecs 2>>error.log)
for bvecs_file in ${bvecs_tmp}; do
	mv ${bvecs_file} ${bvecs_file:0:${#bvecs_file}-1}
done

# check fieldmap
n_b0=$(ls *b0*.nii.gz | wc -l)
n_dwi=$(ls *dwi*.nii.gz | wc -l)
n_dwi=$[${n_b0}+${n_dwi}]

if [ ${n_dwi} -eq "1" ] && [ -d "${BIDSDir}/fmap/" ]; then

	cd ${PreprocDir}/0_BIDS_NIFTI
	dwi_file=($(ls *dwi*.nii.gz))
	dwi_file=${dwi_file[0]}
	dwi_dim=($(mrinfo -size ${dwi_file}))

	cd ${BIDSDir}/fmap/
	fmap_name_all=$(ls *)
	fmap_file=($(ls *.nii*))
	fmap_file=${fmap_file[0]}
	fmap_dim=($(mrinfo -size ${fmap_file}))

	if [ "${dwi_dim[0]}" -eq "${fmap_dim[0]}" ] && [ "${dwi_dim[2]}" -eq "${fmap_dim[2]}" ]; then
		cd ${PreprocDir}/0_BIDS_NIFTI
		for fmap_name in ${fmap_name_all}; do
			/bin/cp -f ${BIDSDir}/fmap/${fmap_name} .
			mv ${fmap_name} dwi_${fmap_name}
		done
	fi
fi

gzip *.nii 2>>error.log
/bin/rm -f error.log

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
json_dir=$(ls -d ${PreprocDir}/0_BIDS_NIFTI/prerename_*dwi*.json)
json_dir_tmp=(${json_dir})
n_json_file=$(ls -d ${PreprocDir}/0_BIDS_NIFTI/prerename_*dwi*.json | wc -l)

mkdir -p ${PreprocDir}/1_DWIprep
cd ${PreprocDir}/1_DWIprep

/bin/rm -f Index_*.txt
/bin/rm -f Acqparams_Topup.txt
/bin/rm -f EddyIndex.txt

# check if .json exist
if [ "${json_dir}" == "" ] || [ "${n_json_file}" -eq "0" ]; then

	cd ${PreprocDir}/1_DWIprep
	n_nifti_file=$(ls -d ${PreprocDir}/0_BIDS_NIFTI/prerename_*dwi*.nii.gz | wc -l)

	if [[ ${n_json_file} -eq "0" ]]; then
	    echo ""
		echo "Error: 0_BIDS_NIFTI is empty."
		echo "Please check BIDS files..."
		exit 1
	fi
else
	
	cd ${PreprocDir}/1_DWIprep
	PhaseEncodingDirectionCode=(0 0 0 0)
	Rec=0

	if [[ ${n_json_file} -gt 1 ]]; then
		
		if [ "${FirstScan}" == "" ] && [ "${SecondScan}" == "" ]; then 
			sn=(0 0)
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

			if [[ ${sn[0]} -eq "0" ]]; then
				echo "Suggest to use 1_DWIprep with -first -second options"
			fi
		fi
	fi

	## read .json file
	for json_file in ${json_dir}; do

		cd ${PreprocDir}/1_DWIprep

		Rec=$[$Rec+1]
		MultibandAccelerationFactor=0
		EPIfactor=0
		EffectiveEchoSpacing=0
		DwellTime=0
		BandwidthPerPixelPhaseEncode=0
		C4=0

		prerename_filename=${json_file:0:${#json_file}-5}
		echo "====Check inforamtion for $(basename ${prerename_filename})===="
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

			'"EchoTime":')
			 	d=${tmp[1]}
				TE=${d:0:${#d}-1}	
				echo "TE: $TE"
			;;

			'"EffectiveEchoSpacing":')
				d=${tmp[1]}
				EffectiveEchoSpacing=${d:0:${#d}-1}	
				echo "EffectiveEchoSpacing: $EffectiveEchoSpacing"
			;;

			'"TotalReadoutTime":')
				d=${tmp[1]}
				TotalReadoutTime=${d:0:${#d}-1}
				echo "TotalReadoutTime: $TotalReadoutTime"
			;;

			'"EchoTrainLength":')
				d=${tmp[1]}
				EPIfactor=${d:0:${#d}-1}
				echo "EPIfactor: $EPIfactor"
			;;

			'"EPIfactor":')
				d=${tmp[1]}
				EPIfactor=${d:0:${#d}-1}
				echo "EPIfactor: $EPIfactor"
			;;

			#'"DwellTime":')
			#	d=${tmp[1]}
			#	DwellTime==${d:0:${#d}-1}
			#	echo "DwellTime: $DwellTime"
			#;;

			#'"PhaseEncodingSteps":')
			#	d=${tmp[1]}
			#	PhaseEncodingSteps==${d:0:${#d}-1}
			#	echo "PhaseEncodingSteps: $PhaseEncodingSteps"
			#;;

			'"BandwidthPerPixelPhaseEncode":')
				d=${tmp[1]}
				BandwidthPerPixelPhaseEncode=${d:0:${#d}-1}
				echo "BandwidthPerPixelPhaseEncode: $BandwidthPerPixelPhaseEncode"
			;;

			'"AcquisitionMatrixPE":')
				d=${tmp[1]}
				AcquisitionMatrixPE=${d:0:${#d}-1}
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
			echo ${MultibandAccelerationFactor} > MBF.txt
		fi

		# C4: total readout time
		if [ `echo "${TotalReadoutTime} > 0" | bc` -eq 1 ]; then
			C4=$(echo "${TotalReadoutTime}")
			echo "<method 1> C4: ${C4}"
		#elif [ `echo "${EPIfactor} > 0" | bc` -eq 1 ] && [ `echo "${EffectiveEchoSpacing} > 0" | bc` -eq 1 ]
		#	C4=$(echo "${EffectiveEchoSpacing}*(${EPIfactor}-1)" | bc)
		#elif [ `echo "${DwellTime} > 0" | bc` -eq 1 ] && [ `echo "${PhaseEncodingSteps} > 0" | bc` -eq 1 ]
		#	C4=$(echo "${DwellTime}*(${PhaseEncodingSteps}-1)" | bc)
		elif [ `echo "${BandwidthPerPixelPhaseEncode} > 0" | bc` -eq 1 ]; then
			C4=$(echo "scale=4; 1/${BandwidthPerPixelPhaseEncode}" | bc)
			echo "<method 2: 1/BW> C4: ${C4}"
		else
			mrconvert ${prerename_filename}.nii.gz -json_import ${json_file} - | mrinfo - -export_pe_eddy Acqparams_Topup_mrconvert.txt indices.txt
			tmp=($(cat Acqparams_Topup_mrconvert.txt))
			echo "<method 3: mrconvet> C4: ${tmp[3]}"
		fi

		if [ -f "Acqparams_Topup_mrconvert.txt" ]; then
			cat Acqparams_Topup_mrconvert.txt >> Acqparams_Topup.txt
			rm -f Acqparams_Topup_mrconvert.txt indices.txt
		elif [ `echo "$C4 > 0" | bc` -eq 1 ]; then
			echo "${Acqparams_Topup_tmp} ${C4}" >> Acqparams_Topup.txt
		else
			echo "<method 4> C4=TE: ${TE}"
			echo "${Acqparams_Topup_tmp} ${TE}" >> Acqparams_Topup.txt
		fi

		## read .bval file
		nn=$(cat ${prerename_filename}.bval)
		for n in ${nn}; do
			echo $Rec >> Eddy_Index.txt
		done

		## rename
		cd ${PreprocDir}/0_BIDS_NIFTI
		for file_format in nii.gz json bval bvec; do
			mv ${prerename_filename}.${file_format} dwi_${PED}.${file_format}
		done
		echo "filename changed from $(basename ${prerename_filename}) to dwi_${PED}"

	done

	cd ${PreprocDir}/1_DWIprep

	## Index_*.txt
	PED_all=${PED_PA}${PED_AP}${PED_RL}${PED_LR}
	echo "PhaseEncodingDirection: ${PED_all}"
	echo "${PhaseEncodingDirectionCode[0]} ${PhaseEncodingDirectionCode[1]} ${PhaseEncodingDirectionCode[2]} ${PhaseEncodingDirectionCode[3]}" > Index_PE.txt
	DirectionNumner=$[${PhaseEncodingDirectionCode[0]}+${PhaseEncodingDirectionCode[1]}+${PhaseEncodingDirectionCode[2]}+${PhaseEncodingDirectionCode[3]}]

	## transform EddyIndex.txt
	EddyIndex=$(cat Eddy_Index.txt)
	echo $EddyIndex > Eddy_Index.txt

fi