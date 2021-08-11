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
VDate=2021.08.11

Usage(){
    cat <<EOF

OGIO - Diffusion MRI processing  v${Version}, ${VDate}

Usage: Main -[options]
Options:
    -proc <output dir>  Output directory
    -bids <BIDS dir>    BIDS file directory
    -arg  <setup file>  configuration file
    -h                  Help

* this script will automatically assign defaults setup if no specific configuration file supplied,
* you can edit the argumets in SetUpOGIOArg.sh

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

# Check if HOGIO variable exists,
HOGIO=$(echo ${HOGIO})
if [[ -z "${HOGIO}" ]]; then
    echoC 1 ""
    echoC 1 "Error: It seems that the HOGIO environment variable is not defined.          "
    echoC 1 "       Run the command 'export HOGIO=/usr/local/OGIO'                        "
    echoC 1 "       changing /usr/local/OGIO to the directory path you installed OGIO to. "
    echoC 1 ""
    exit 1
fi
if [[ ! -d ${HOGIO} ]]; then
    echoC 1 ""
    echoC 1 "Error: ${HOGIO}"
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
        argFile=${HOGIO}/SetUpOGIOArg.sh
        source source ${argFile}
    fi
else    
    echoC 2 "No configuration file apply."
    argFile=${HOGIO}/SetUpOGIOArg.sh
    source source ${argFile}
fi

aStep=(${Step//./ })
runStep=($(echo "${aStep[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [[ "1" -eq "${cuda}" ]]; then
    step3Arg="-c"
    if [[ "1" -eq "${stv}" ]]; then
        step3Arg="${step3Arg} -m"
    fi
fi
if [[ "1" -eq "${rsimg}" ]]; then
    step3Arg="${step3Arg} -r"
fi

if [[ ! -z "${bzero}" ]]; then
    step2Arg="${step2Arg} -t ${bzero}"
    step3Arg="${step3Arg} -t ${bzero}"
    step5Arg="${step5Arg} -t ${bzero}"
    step6Arg="${step6Arg} -t ${bzero}"
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

    fi
fi
if [[ ! -z "${trkNum}" ]]; then
    step7Arg="${step7Arg} -n ${trkNum}"
fi

pinfo="\n"
pinfo+="[Diffusion data processing pipeline] v${Version} ${VDate}"
echoC 2 "$pinfo" ${SubjectDir}/mainlog.txt
pinfo="Start process at $(date +"%Y-%m-%d %T")\n"
pinfo+="Subject ProcDir: ${SubjectDir}\n"
pinfo+="---------------------------------------------------------\n"
pinfo+="SetupFile: ${argFile}\n"
pinfo+="processing steps: ${Step}\n"
pinfo+="Bzero threshold: ${bzero}\n"
pinfo+="AtlasDir=${AtlasDir}\n"
pinfo+="trkNum=${trkNum}\n"
echoC 0 "$pinfo" ${SubjectDir}/mainlog.txt

for (( i = 0; i < ${#runStep[@]}; i++ )); do
    #statements
    case ${runStep[i]} in
        1 )
            # Step 1_DWIprep
            STARTTIME=$(date +"%s")
            echoC 2 "1_DWIprep at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${HOGIO}/1_DWIprep.sh -b $BIDSDir -p $SubjectDir | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        2 )
            # Step 2_BiasCo
            STARTTIME=$(date +"%s")
            echoC 2 "2_BiasCo at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${HOGIO}/2_BiasCo.sh -p $SubjectDir ${step2Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        3 )
            # Step 3_EddyCo
            STARTTIME=$(date +"%s")
            echoC 2 "3_EddyCo at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${HOGIO}/3_EddyCo.sh -p $SubjectDir ${step3Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        4 )
            # Step 4_T1preproc
            STARTTIME=$(date +"%s")
            echoC 2 "4_T1preproc at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt            
            bash ${HOGIO}/4_T1preproc.sh -p $SubjectDir ${step4Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        5)    
            # Step 5_DTIFIT
            STARTTIME=$(date +"%s")
            echoC 2 "5_DTIFIT at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt
            bash ${HOGIO}/5_DTIFIT.sh -p $SubjectDir ${step5Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        6 )
            # Step 6_CSDpreproc
            STARTTIME=$(date +"%s")
            echoC 2 "6_CSDpreproc at $(date +"%Y-%m-%d %T")" ${SubjectDir}/mainlog.txt            
            bash ${HOGIO}/6_CSDpreproc.sh -p $SubjectDir ${step6Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        7 )
            # Step 7_NetworkProc
            STARTTIME=$(date +"%s")
            echoC 2 "7_NetworkProc at $(date +"%Y-%m-%d %T")"  ${SubjectDir}/mainlog.txt            
            bash ${HOGIO}/7_NetworkProc.sh -p $SubjectDir ${step7Arg} | tee -a ${SubjectDir}/mainlog.txt
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
    esac
done

pinfo="End process at $(date +"%Y-%m-%d %T")"
echoC 2 "$pinfo" ${SubjectDir}/mainlog.txt
echo ""
