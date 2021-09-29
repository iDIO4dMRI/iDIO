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
# 20200807 - bugdix C4=TE
# 20200826 - check C4 from mrconvert and add mrconvert function (use mrconvert)
# 20201229 - bug fixed (bc)
# 20210122 - fmap, 1 phase encoding direction
# 20210821 - total readout time
##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage() {
    cat<<EOF
    
    dMRI processing  v1.0

    1_DWIprep - DWI data preperation for the following processing

    Usage: 1_DWIprep -b <BIDSDir> -p <PreprocDir>
    
    Options:
	-s 	Please provide the series of phase-encoding direction {PA, AP, RL, LR} 
		Two scans for AP and PA  => 2 1 0 0
		One scan for PA => 1 0 0 0


EOF
    exit
}

SubjName=
BIDSDir=
PreprocDir=
C4=
PhaseEncoding=

while getopts "hb:p:c:s:v" OPTION
do
    case $OPTION in
    h)  
        Usage
        ;; 
    b)
        BIDSDir=$OPTARG
        ;;
    p)
        PreprocDir=$OPTARG
        ;;
    s)
        PhaseEncoding=$OPTARG
        ;;
    v)
        verbose=1
        ;;
    ?)
        Usage
        ;;
    esac
done

if [ "${PreprocDir}" == "" ] || [ "${BIDSDir}" == "" ]; then
    Usage
fi

mkdir -p ${PreprocDir}/0_BIDS_NIFTI
cd ${PreprocDir}/0_BIDS_NIFTI
/bin/cp -f ${BIDSDir}/dwi/*b0* .
/bin/cp -f ${BIDSDir}/dwi/*dwi* .
/bin/cp -f ${BIDSDir}/dwi/*DWI* .
/bin/cp -f ${BIDSDir}/anat/*t1* .
/bin/cp -f ${BIDSDir}/anat/*T1* .

# compress
gzip *.nii

# check fieldmap
n_b0=$(ls *b0*.nii.gz | wc -l)
n_dwi=$(ls *dwi*.nii.gz | wc -l)
n_DWI=$(ls *DWI*.nii.gz | wc -l)
n_dwi=$[${n_b0}+${n_dwi}+${n_DWI}]

if [ ${n_dwi} -eq "1" ] && [ -d "${BIDSDir}/fmap/" ]; then

	cd ${BIDSDir}/fmap/
	fmap_name_all=$(ls *)

	cd ${PreprocDir}/0_BIDS_NIFTI

	for fmap_name in ${fmap_name_all}; do
		/bin/cp -f ${BIDSDir}/fmap/${fmap_name} .
		mv ${fmap_name} dwi_${fmap_name}
	done

fi

gzip *.nii


# check filenames
for T1_file in *T1*.nii.gz; do
 	mv ${T1_file} T1w.nii.gz
done

for T1_file in *T1*.json; do
 	mv ${T1_file} T1w.json
done

for T1_file in *t1*.nii.gz; do
 	mv ${T1_file} T1w.nii.gz
done

for T1_file in *t1*.json; do
 	mv ${T1_file} T1w.json
done

for DWI_file in *DWI*; do
	nname=$(echo ${DWI_file} | sed 's/DWI/dwi/g')
 	mv ${DWI_file} $nname
done

for b0_file in *b0*; do
	nname=$(echo ${b0_file} | sed 's/b0/dwi_b0/g')
 	mv ${b0_file} $nname
done

bvals_tmp=$(ls -f *.bvals 2>>error.log) 
for bvals_file in ${bvals_tmp}; do
	mv ${bvals_file} ${bvals_file:0:${#bvals_file}-1}
done

bvecs_tmp=$(ls -f *.bvecs 2>>error.log)
for bvecs_file in ${bvecs_tmp}; do
	mv ${bvecs_file} ${bvecs_file:0:${#bvecs_file}-1}
done

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
if [ "${json_dir}" == "" ] || [ "${n_json_file}" == "0" ]; then

	cd ${PreprocDir}/1_DWIprep
	n_nifti_file=$(ls -d ${PreprocDir}/0_BIDS_NIFTI/prerename_*dwi*.nii.gz | wc -l)

	if [[ ${n_json_file} -eq 0 ]]; then
	    echo ""
		echo "Error: 0_BIDS_NIFTI is empty."
		echo "Please check BIDS files..."
		exit 1
	else

		for dwi_files in *dwi*; do
			mv ${dwi_files} ${dwi_files:10:${#dwi_files}-10}
		done

		PhaseEncodingDirectionCode=(${PhaseEncoding}})
		Rec=0

		Topup=$((${PhaseEncodingDirectionCode[0]} + ${PhaseEncodingDirectionCode[1]} + ${PhaseEncodingDirectionCode[2]} + ${PhaseEncodingDirectionCode[3]}))

		if [ $Topup -gt 1 ]; then
			PE=($(echo PA AP RL LR))
			for Order in {0..3}; do
				if [ ${PhaseEncodingDirectionCode[${Order}]} == "1" ]; then
		   			direction[0]=${PE[${Order}]}
				fi

				if [ ${PhaseEncodingDirectionCode[${Order}]} == "2" ]; then
		    		direction[1]=${PE[${Order}]}
				fi
			done

			for d in ${direction}; do
				Rec=$[$Rec+1]
				for bval_files in *${d}.bval; do
					nn=$(cat ${bval_files})
					for n in ${nn}; do
						echo $Rec >> Eddy_Index.txt
					done
				done

				case "$d" in			
				"PA")
					Acqparams_Topup_tmp="0 1 0" 
					;;
				"AP") 
					Acqparams_Topup_tmp="0 -1 0"
					;;
				"RL") 
					Acqparams_Topup_tmp="1 0 0"
					;;
				"LR") 
					Acqparams_Topup_tmp="-1 0 0" 
					;;
				esac

				echo "${Acqparams_Topup_tmp} ${C4}" >> Acqparams_Topup.txt
			done
		fi

		echo "${PhaseEncodingDirectionCode[0]} ${PhaseEncodingDirectionCode[1]} ${PhaseEncodingDirectionCode[2]} ${PhaseEncodingDirectionCode[3]}" > Index_PE.txt
	fi
else
	
	cd ${PreprocDir}/1_DWIprep
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

		cd ${PreprocDir}/1_DWIprep

		Rec=$[$Rec+1]
		MultibandAccelerationFactor=0
		EPIfactor=0
		EffectiveEchoSpacing=0
		DwellTime=0
		BandwidthPerPixelPhaseEncode=0
		C4=0

		prerename_filename=${json_file:0:${#json_file}-5}
		echo "\\n====Check inforamtion for $(basename ${prerename_filename})====\n"
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
		if [ "$TotalReadoutTime" != 0 ]; then
			C4=$(echo "${TotalReadoutTime}")
			echo "<method 1> C4: ${C4}"
		#elif [ "$EPIfactor" != 0 ] && [ "$EffectiveEchoSpacing" != 0 ]; then
		#	C4=$(echo "${EffectiveEchoSpacing}*(${EPIfactor}-1)" | bc)
		#elif [ "$DwellTime" != 0 ] && [ "$PhaseEncodingSteps" != 0 ]; then
		#	C4=$(echo "${DwellTime}*(${PhaseEncodingSteps}-1)" | bc)
		elif [ "$BandwidthPerPixelPhaseEncode" != 0 ]; then
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
		elif [ "$C4" != 0 ]; then
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