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
Version=1.0
VDate=2020/07/30

Usage(){
    cat <<EOF
    
dMRI processing  v${Version}, ${VDate}

Main - Diffusion data processing pipeline
       "MRtrix3" "MatlabR2018b: spm12, export_fig" "FSL 6.0.3" "ANTs"
       is needed for this script.
    
Usage: Main -[options]   

System will automatically detect all folders in directory if no input arguments supplied

Options:
    -p  Output directory
    -b 	BIDS file directory
    -c  Using CUDA to speed up. NVIDIA GPU with CUDA v9.1 is available to use this option.
    -a  Input Atlas directory; [default = pwd/configure_Atlas, need to include Atlas/MNI directories

EOF
exit 1
}

SubjectDir=
BIDSDir=
mainS=$(pwd)
cuda=0

while getopts "hp:b:ca:v" OPTION
do
    case $OPTION in
    p)
        SubjectDir=$OPTARG;;
    b)
        BIDSDir=$OPTARG;;
    c)
		cuda=1;;
    a) 
        AtlasDir=$OPTARG;;
    v)
        verbose=1;;
    ?)
        Usage;;
    esac
done

if [ "$SubjectDir" == "" ]; then
    Usage;
fi

CalElapsedTime(){ #STARTTIME #mainlog.txt
    ENDTIME=$(date +"%s")
    duration=$(($ENDTIME - $1))
    echo "-------------$(date +"%Y-%m-%d %T") ## $((duration / 60)):$((duration % 60))" >> $2
}

echo "[Diffusion data processing pipeline] v${Version} ${VDate}"
echo "Start process at $(date +"%Y-%m-%d %T")"


echo "[Diffusion data processing pipeline] v${Version} ${VDate}" >> ${SubjectDir}/mainlog.txt 
echo "${SubjectDir}" >> ${SubjectDir}/mainlog.txt

#echo Start at $(date +"%Y-%m-%d %T") >> ${SubjectDir}/mainlog.txt
# Step 1_DWIprep
echo " " >> ${SubjectDir}/mainlog.txt
STARTTIME=$(date +"%s")
echo "1_DWIprep at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
sh 1_DWIprep.sh -b $BIDSDir -p $SubjectDir
CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt


# Step 2_BiasCo
echo " " >> ${SubjectDir}/mainlog.txt
STARTTIME=$(date +"%s")
echo "2_BiasCo at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
sh 2_BiasCo.sh -p $SubjectDir
CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt


# Step 3_EddyCo
echo " " >> ${SubjectDir}/mainlog.txt
STARTTIME=$(date +"%s")
echo "3_EddyCo at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
case ${cuda} in 
	0) # without cuda
		sh 3_EddyCo.sh -p $SubjectDir;;
	1) # with cuda
		sh 3_EddyCo.sh -p $SubjectDir -c -m;;
esac
CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt


# Step 4_DTIFIT
echo " " >> ${SubjectDir}/mainlog.txt
STARTTIME=$(date +"%s")
echo "4_DTIFIT at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
sh 4_DTIFIT.sh -p $SubjectDir -s $mainS
CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt


# Step 5_CSDpreproc
echo " " >> ${SubjectDir}/mainlog.txt
STARTTIME=$(date +"%s")
echo "5_CSDpreproc at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
sh 5_CSDpreproc.sh -p $SubjectDir
CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt


# Step 6_NetworkProc
echo " " >> ${SubjectDir}/mainlog.txt
STARTTIME=$(date +"%s")
echo "6_NetworkProc at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
if [ -z "${AtlasDir}" ]; then
    sh 6_NetworkProc.sh -p $SubjectDir
else
    sh 6_NetworkProc.sh -p $SubjectDir -a AtlasDir
fi
CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt


echo "End process at $(date +"%Y-%m-%d %T")"
