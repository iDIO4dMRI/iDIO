#!/bin/bash
# Programs:
# transform dicom to BIDS folder's format
# writed by Yu-Ting Ko version.1
# 2020.02.01
# required: gdcmconv

#PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/binf:/home/z4/Desktop/mricron
#export PATH

echo "[dcm2bids] v1.0 2020/02/01"
echo "Start process at $(date)"


# pause function
function pause(){
   read -p "$*"
}


# check input path or data
if [ "${1}" == "-p" ]; then # for group data
	if [ "${2}" == "" ]; then
		echo "[Error:dcm2bids] the process exits without path"
		exit 1
	else
		if [[ $(find ${2}) ]]; then
			echo "Your input path is ${2}"
			folder_input=${2}
		else
			echo "[Error:dcm2bids] the process exits without path"
			exit 1
		fi
	fi
elif [ "${1}" == "-d" ]; then # for single data
	if [ "${2}" == "" ]; then
		echo "[Error:dcm2bids] the process exits without data"
		exit 1
	else
		if [[ $(find ${2}) ]]; then
			echo "Your input data is ${2}"
			folder_input=${2}
		else
			echo "[Error:dcm2bids] the process exits without data"
			exit 1
		fi
	fi
else
	echo "[Error:dcm2bids] the process exits without data or path"
	exit 1
fi


# check output path
if [ "${3}" == "-o" ]; then
	if [ "${4}" == "" ]; then
		echo "[Error:dcm2bids] the process exits without output path"
		exit 1
	else
		if [[ $(find ${4}) ]]; then
			echo "Your output path is ${4}"
			folder_output=${4}
			mkdir "${folder_output}/DICOM"
			mkdir "${folder_output}/BIDS"
		else
			echo "[Warning:dcm2bids] Output path can not been found (Create a new folder with ${4})"
			mkdir ${4}
			folder_output=${4}
			mkdir "${folder_output}/DICOM"
			mkdir "${folder_output}/BIDS"
		fi
	fi
else
	echo "[Error:dcm2bids] the process exits without output path"
	exit 1
fi


# main code
cd ${folder_input}
echo "cd to ${folder_input}"

# check sub-??? in output folder
# if [[ $(find "${folder_output}/DICOM/sub-*" | find "${folder_output}/BIDS/sub-*") ]]; then
# 	last=$(ls ${folder_output} | sed 's/sub-0*//g' | sort -n | tail -1)
# else
# 	last=0
# fi
last=0

# start run each subject's MRI folder and transfer every sequence from Dicom to Nifiti
for folder_num in *; do
	cd "${folder_input}/${folder_num}"
	echo "Found subject folder: .${folder_input}/${folder_num}"
	last=$((${last}+1))
	folder_sub=$(printf '%s%04d' "sub-" "${last}")
	mkdir "${folder_output}/DICOM/${folder_sub}"
	mkdir "${folder_output}/BIDS/${folder_sub}"
	echo "Create a new folder in the ${folder_output} : ${folder_sub}"

	# check MRI folder
	pwd
	folder_mri=$(find \( -name "MRI*" -o -name "Mri*" -o -name "mri*" -o -name "MR*" \) | sed 's/^..//g')
	if [ "${folder_mri}" != "" ]; then
		cd "${folder_input}/${folder_num}/${folder_mri}"
		echo "Found MRI folder: .${folder_input}/${folder_num}/${folder_mri}"


		# check dicom folders and the dicom filename must be "IM*0001.dcm"
		#mapfile -d $'\0' folder_array < <(find . -name "IM*0001.dcm" -print0) 
		folder_array=($(find . -name "IM*0001.dcm"))
		len=${#folder_array[*]}
		echo "And ${len} folders were found in the ./${folder_mri}"
		for folder_mri_num in "${folder_array[@]}"; do
			folder_mri_num_path=$(dirname ${folder_mri_num} | sed 's/^..//g')
			cd "${folder_input}/${folder_num}/${folder_mri}/${folder_mri_num_path}"
			echo "cd to ${folder_input}/${folder_num}/${folder_mri}/${folder_mri_num_path}"


			# find the number of dicom files
			dicom_number=$(ls -l|grep "^-"| wc -l)
			if [ "${dicom_number}" != "" ]; then
				echo "Found ${dicom_number} DICOM file(s) in the folder"


				# find the name of session
				period=$(echo ${folder_mri_num_path} | grep -o -e pre-op -e intra-op -e post-op)
				declare -A period_array
				period_array=([pre-op]=ses-1 [post-op]=ses-2 [intra-op]=ses-3)
				if [ "${period}" != "" ]; then
					if [[ $(find "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}" | \
						find "${folder_output}/BIDS/${folder_sub}/${period_array[${period}]}") ]]; then
						echo "${period_array[${period}]} already exists"
					else
						mkdir "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}"
						mkdir "${folder_output}/BIDS/${folder_sub}/${period_array[${period}]}"
						echo "Create a session folder : ${period} -> ${period_array[${period}]}"
					fi
				else
					mkdir "${folder_output}/DICOM/${folder_sub}/ses-1"
					mkdir "${folder_output}/BIDS/${folder_sub}/ses-1"
					period="pre-op"
					echo " Only session-1 folder will be created"
				fi


				# find the name of mri sequences
				IFS="/" read -ra sequence <<< ${folder_mri_num_path}
				seqs_name=$(echo ${sequence[-1]} | grep -i -o -e "T1" -e "MPRAGE" -e "t2" -e "flair" -e "DTI" -e "diff" -e "bold" -e "REST" -e "TUPIAN" -e "YUNDONG" -e "TOF")
				IFS=" " read -ra seq_name <<< ${seqs_name}
				declare -A seq_array
				seq_array=(["T1"]=anat ["MPRAGE"]=anat ["t2"]=anat ["flair"]=anat ["DTI"]=dwi ["diff"]=dwi ["bold"]=func ["REST"]=func ["TUPIAN"]=func ["YUNDONG"]=func ["TOF"]=TOF)
				if [ "${seq_name}" != "" ]; then
					if [[ $(find "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}" | \
						find "${folder_output}/BIDS/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}") ]]; then	
						echo "${seq_array[${seq_name}]} already exists"
					else
						mkdir "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}"
						mkdir "${folder_output}/BIDS/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}"
						echo "Create a sequence folder : ${sequence[-1]} -> ${seq_array[${seq_name}]}"
					fi
				else
					echo "[Error:dcm2bids] Can't recognize the sequence name: ${sequence[-1]}"
					exit 1
				fi


				# when the folder have same sequence name
				seq_name_num=1
				seq_name_new=$(printf '%s%02d' "${seq_name}-" "${seq_name_num}")
				if [[ $(find "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}" | \
					find "${folder_output}/BIDS/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}") ]]; then
					echo "${seq_name_new} already exists"
					seq_name_num=$((${seq_name_num}+1))
					seq_name_new=$(printf '%s%02d' "${seq_name}-" "${seq_name_num}")
					mkdir "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}"
					mkdir "${folder_output}/BIDS/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}"
				else
					mkdir "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}"
					mkdir "${folder_output}/BIDS/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}"
				fi
				

				# check the dicom file is "real" dicom and copy to folder_output/DICOM/...
				echo "Output DICOM to ${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}"
				dcm_image=$(ls)
				for num_image in ${dcm_image}; do
					#gdcmconv --raw -i ${num_image} -o "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}/${num_image}"
					cp ${num_image} "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}/${num_image}"
				done


				# run dcm2niix and save nifiti to folder_output/BIDS/...
				echo "Output Nifiti to ${folder_output}/BIDS/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}"
				dcm2niix -o "${folder_output}/BIDS/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}" \
				-f "${folder_sub}_${period_array[${period}]}_${seq_array[${seq_name}]}" \
				-z y "${folder_output}/DICOM/${folder_sub}/${period_array[${period}]}/${seq_array[${seq_name}]}/${seq_name_new}"
			else
				echo "Found 0 DICOM file(s) in the folder"
			fi			
		done
		#pause 'Press [Enter] key to continue...'			
	else
		echo "[Warning:dcm2bids] Can't find the MRI folder...... ./${folder_mri}......Pass"
	fi
done

echo
echo "[Finish:dcm2bids] the process exits without error at $(date)"
echo
