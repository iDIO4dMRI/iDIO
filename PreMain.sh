#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Kuantsen Kuo
## Version 1.0 /2020/03/10
##
## Edit: Step 2, 2020/04/07, Tsen
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

Usage(){
    cat <<EOF
    
dMRI processing  v1.0

PreMain - Diffusion data processing pipeline
        "MRtrix3" "MatlabR2018b: spm12, export_fig" "FSL 6.0.3"
        is needed for this script.
    
Usage: PreMain -[options]   

System will automatically detect all folders in directory if no input arguments supplied

Options:
    -p  Output directory
    -b 	BIDS file directory
    -c  Using CUDA to speed up. NVIDIA GPU with CUDA v9.1 or CUDA v8.0 is available to use this option.

EOF
exit 1
}

SubjectDir=
BIDSDir=
mainS=$(pwd)
cuda=0

while getopts "hp:b:cv" OPTION
do
    case $OPTION in
    p)
        SubjectDir=$OPTARG
        ;;
    b)
		BIDSDir=$OPTARG
		;;
    c)
		cuda=1
		;;
    v)
        verbose=1
        ;;
    ?)
        Usage
        ;;
    esac
done

if [ "$SubjectDir" == "" ]; then
    Usage
fi

echo "[Diffusion data processing pipeline] v1.0 2020/03/10"
echo "Start process at $(date +"%Y-%m-%d %T")"


echo "[Diffusion data processing pipeline] v1.0 2020/03/10" >> ${SubjectDir}/pretime.log 
echo "${SubjectDir}" >> ${SubjectDir}/pretime.log

#echo Start at $(date +"%Y-%m-%d %T") >> ${SubjectDir}/pretime.log
# Step 1_DWIprep
echo " " >> ${SubjectDir}/pretime.log
STARTTIME=$(date +"%s")
echo "1_DWIprep at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/pretime.log

sh 1_DWIprep.sh -b $BIDSDir -p $SubjectDir -s TEST0001

ENDTIME=$(date +"%s"); duration=$(($ENDTIME - $STARTTIME))
echo "-------------$(date +"%Y-%m-%d %T") ## $((duration / 60)):$((duration % 60))" >> ${SubjectDir}/pretime.log


# Step 2_BiasCo
echo " " >> ${SubjectDir}/pretime.log
STARTTIME=$(date +"%s")
echo "2_BiasCo at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/pretime.log

sh 2_BiasCo.sh -p $SubjectDir

ENDTIME=$(date +"%s"); duration=$(($ENDTIME - $STARTTIME))
echo "------------$(date +"%Y-%m-%d %T") ## $((duration / 60)):$((duration % 60))" >> ${SubjectDir}/pretime.log


# Step 3_EddyCo
echo " " >> ${SubjectDir}/pretime.log
STARTTIME=$(date +"%s")
echo "3_EddyCo at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/pretime.log

case ${cuda} in 
	0) # without cuda
		sh 3_EddyCo.sh -p $SubjectDir
		;;
	1) # with cuda
		sh 3_EddyCo.sh -p $SubjectDir -c -m
        ;;
esac

ENDTIME=$(date +"%s"); duration=$(($ENDTIME - $STARTTIME))
echo "------------$(date +"%Y-%m-%d %T") ## $((duration / 60)):$((duration % 60))" >> ${SubjectDir}/pretime.log


# Step 4_DTIFIT
echo " " >> ${SubjectDir}/pretime.log
STARTTIME=$(date +"%s")
echo "4_DTIFIT at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/pretime.log
sh 4_DTIFIT.sh -p $SubjectDir -s $mainS
ENDTIME=$(date +"%s"); duration=$(($ENDTIME - $STARTTIME))
echo "------------$(date +"%Y-%m-%d %T") ## $((duration / 60)):$((duration % 60))" >> ${SubjectDir}/pretime.log


echo "End process at $(date +"%Y-%m-%d %T")"
