#!/bin/bash

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Kuantsen Kuo
## Version 1.0 /2020/03/10
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################
Version=1.0
VDate=2021.10.20

Usage(){
    cat <<EOF

iDIO - integrated Diffusion Image Operator  v${Version}, ${VDate}

Usage: Main -[options]
Options:
    -proc <output dir>  Output directory
    -bids <BIDS dir>    BIDS file directory
    -arg  <setup file>  configuration file
    -h                  Help

* this script will automatically assign defaults setup if no specific configuration file supplied,
* you can edit the argumets in SetUpiDIOArg.sh

EOF
exit 1
}

function CalElapsedTime(){ #STARTTIME #mainlog.txt
    ENDTIME=$(date +"%s")
    duration=$(($ENDTIME - $1))
    echo -e "-------------$(date +"%Y-%m-%d %T") ## $((duration / 60)):$((duration % 60))\n" >> $2
}
function echoC(){ #color #string #mainlog.txt
    tput setaf $1
    echo -e "$2"  | tee -a $3
    tput sgr0
}

# Check if HiDIO variable exists,
iDIO_HOME=$(echo ${iDIO_HOME})
if [[ -z "${iDIO_HOME}" ]]; then
    echoC 1 ""
    echoC 1 "Error: It seems that the iDIO_HOME environment variable is not defined.          "
    echoC 1 "       Run the command 'export iDIO_HOME=/usr/local/iDIO'                        "
    echoC 1 "       changing /usr/local/iDIO to the directory path you installed iDIO to. "
    echoC 1 ""
    exit 1
fi
if [[ ! -d ${iDIO_HOME} ]]; then
    echoC 1 ""
    echoC 1 "Error: ${iDIO_HOME}"
    echoC 1 "       does not exist. Check that this value is correct."
    echoC 1 ""
    exit 1
fi

SubjectDir=
BIDSDir=
argFile=
while [ "$#" -gt 0 ]; do
    case "$1" in
    -proc)  SubjectDir="$2"; shift; shift;;
    -bids)  BIDSDir="$2"; shift; shift;;
    -arg)   argFile="$2"; shift; shift;;
    -h) Usage;;

    *) echo "unknown option:" "$1"; exit 1;;
    esac
done

# Check if input variable exists
if  [ "${BIDSDir}" == "" ] || [ "${SubjectDir}" == "" ]; then
    Usage;
fi
if [[ ! -d ${SubjectDir} ]]; then
    echoC 2 "${SubjectDir} does not exist ... creating"
    mkdir -p ${SubjectDir}
fi
if [[ ! -d ${BIDSDir} ]]; then
    echoC 1 "Error: ${BIDSDir}"
    echoC 1 "       does not exist. Check that this value is correct."
    echoC 1 ""
    exit 1
fi
if [[ ! -z ${argFile} ]]; then
    if [[ -f ${argFile} ]]; then
        source ${argFile}
    else
        echoC 2 "${argFile}"
        echoC 2 "       does not exist. Loading defaults setup ..."
        argFile=${iDIO_HOME}/SetUpiDIOArg.sh
        source ${argFile}
    fi
else
    echoC 2 "No configuration file apply."
    argFile=${iDIO_HOME}/SetUpiDIOArg.sh
    source ${argFile}
fi

aStep=(${Step//./ })
runStep=($(echo "${aStep[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [[ ! -z "${first}" ]] && [ ! -z "${second}" ] ; then
    step1Arg="-first ${first} -second ${second}"
fi

if [[ "1" -eq "${cuda}" ]]; then
    step3Arg="-c"
    if [[ "1" -eq "${stv}" ]]; then
        step3Arg="${step3Arg} -m"
    fi
fi

if [[ `echo ${rsimg}'>'0 | bc -l` -eq 1 ]]; then
    step3Arg="${step3Arg} -r ${rsimg}"
fi

if [[ ! -z "${bzero}" ]]; then
    step2Arg="${step2Arg} -t ${bzero}"
    step3Arg="${step3Arg} -t ${bzero}"
    step5Arg="${step5Arg} -t ${bzero}"
    step6Arg="${step6Arg} -t ${bzero}"
    step8Arg="${step8Arg} -t ${bzero}"
fi


if [[ ! -z "${AtlasDir}" ]]; then
    if [[ ! -d ${AtlasDir} ]]; then
        echoC 1 "Error: ${AtlasDir}"
        echoC 1 "       does not exist. Check that this value is correct."
        echoC 1 ""
        exit 1
    else
        step4Arg="${step4Arg} -a ${AtlasDir}"
        step7Arg="${step7Arg} -a ${AtlasDir}"
        step8Arg="${step8Arg} -a ${AtlasDir}"

    fi
fi
if [[ ! -z "${trkNum}" ]]; then
    step7Arg="${step7Arg} -n ${trkNum}"
fi

pinfo="
[Diffusion data processing pipeline] v${Version} ${VDate}
Start process at $(date +"%Y-%m-%d %T")
Subject ProcDir: ${SubjectDir}"
echoC 2 "$pinfo" ${SubjectDir}/mainlog.txt
pinfo="---------------------------------------------------------
SetupFile:          ${argFile}
processing steps:   ${Step}
B-zero threshold:   ${bzero}
AtlasDir:           ${AtlasDir}
trkNum:             ${trkNum}"
if [[ `echo ${rsimg}'>'0 | bc -l` -eq 1 ]]; then
    pinfo="${pinfo}
isotropic voxels:   ${rsimg}(mm)"
fi
echoC 3 "$pinfo" ${SubjectDir}/mainlog.txt

for (( i = 0; i < ${#runStep[@]}; i++ )); do
    #statements
    case ${runStep[i]} in
        1 )
            # Step 1_DWIprep
            STARTTIME=$(date +"%s")
            echoC 2 "1_DWIprep at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${iDIO_HOME}/1_DWIprep.sh -b $BIDSDir -p $SubjectDir ${step1Arg}| tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        2 )
            # Step 2_BiasCo
            STARTTIME=$(date +"%s")
            echoC 2 "2_BiasCo at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${iDIO_HOME}/2_BiasCo.sh -p $SubjectDir ${step2Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        3 )
            # Step 3_EddyCo
            STARTTIME=$(date +"%s")
            echoC 2 "3_EddyCo at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${iDIO_HOME}/3_EddyCo.sh -p $SubjectDir ${step3Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        4 )
            # Step 4_T1preproc
            STARTTIME=$(date +"%s")
            echoC 2 "4_T1preproc at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${iDIO_HOME}/4_T1preproc.sh -p $SubjectDir ${step4Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        5)
            # Step 5_DTIFIT
            STARTTIME=$(date +"%s")
            echoC 2 "5_DTIFIT at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${iDIO_HOME}/5_DTIFIT.sh -p $SubjectDir ${step5Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        6 )
            # Step 6_CSDpreproc
            STARTTIME=$(date +"%s")
            echoC 2 "6_CSDpreproc at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${iDIO_HOME}/6_CSDpreproc.sh -p $SubjectDir ${step6Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        7 )
            # Step 7_NetworkProc
            STARTTIME=$(date +"%s")
            echoC 2 "7_NetworkProc at $(date +"%Y-%m-%d %T")"  ${SubjectDir}/mainlog.txt
            bash ${iDIO_HOME}/7_NetworkProc.sh -p $SubjectDir ${step7Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        8)
            STARTTIME=$(date +"%s")
            echoC 2 "8_QC at $(date +"%Y-%m-%d %T")"  ${SubjectDir}/mainlog.txt
            python3 ${iDIO_HOME}/python/iDIO/run_iDIOQC.py -p ${SubjectDir} ${step8Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
    esac
done

pinfo="End process at $(date +"%Y-%m-%d %T")"
echoC 2 "$pinfo" ${SubjectDir}/mainlog.txt
echo ""
