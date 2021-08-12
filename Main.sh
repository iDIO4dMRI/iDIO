#!/bin/bash

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Kuantsen Kuo
## Version 1.0 /2020/03/10
##
## Edit: parse command args, 2020/08/03, Kuo
## Edit: add SetUpOGIOEnv.sh, 2021/02/03, Kuo
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################
Version=1.0
VDate=2021.07.22

Usage(){
    cat <<EOF

OGIO - Diffusion MRI processing  v${Version}, ${VDate}

Usage: Main -[options]
Options:
    -proc <output dir>  Output directory
    -bids <BIDS dir>    BIDS file directory
    -h                  Help

* this script will automatically assign defaults setup if no specific arguments supplied,
* you can edit the argumets in SetUpOGIOArg.sh

EOF
exit 1
}

# Check if HOGIO variable exists,
HOGIO=$(echo ${HOGIO})
if [[ -z "${HOGIO}" ]]; then
    echo ""
    echo "Error: It seems that the HOGIO environment variable is not defined.          "
    echo "       Run the command 'export HOGIO=/usr/local/OGIO'                        "
    echo "       changing /usr/local/OGIO to the directory path you installed OGIO to. "
    echo ""
    exit 1
fi
if [[ ! -d ${HOGIO} ]]; then
    echo ""
    echo "Error: ${HOGIO}"
    echo "       does not exist. Check that this value is correct."
    echo ""
    exit 1
fi

source ${HOGIO}/SetUpOGIOArg.sh
aStep=(${Step//./ })
runStep=($(echo "${aStep[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [[ "1" -eq "${cuda}" ]]; then
    step3Arg="-c"
    if [[ "1" -eq "${stv}" ]]; then
        step3Arg="${step3Arg} -m"
    fi
fi
if [[ "${rsimg}" -gt "0" ]]; then
    step3Arg="${step3Arg} -r ${rsimg}"
fi

if [[ ! -z "${bzero}" ]]; then
    step2Arg="${step2Arg} -t ${bzero}"
    step3Arg="${step3Arg} -t ${bzero}"
    step5Arg="${step5Arg} -t ${bzero}"
    step6Arg="${step6Arg} -t ${bzero}"
fi


if [[ ! -z "${AtlasDir}" ]]; then
    if [[ ! -d ${AtlasDir} ]]; then
        echo "Error: ${AtlasDir}"
        echo "       does not exist. Check that this value is correct."
        echo ""
        exit 1
    else
        step4Arg="${step4Arg} -a ${AtlasDir}"
        step7Arg="${step7Arg} -a ${AtlasDir}"

    fi
fi
if [[ ! -z "${trkNum}" ]]; then
    step7Arg="${step7Arg} -n ${trkNum}"
fi

SubjectDir=
BIDSDir=
while [ "$#" -gt 0 ]; do
    case "$1" in
    -proc)  SubjectDir="$2"; shift; shift;;
    -bids)  BIDSDir="$2"; shift; shift;;
    -h) Usage;;

    *) echo "unknown option:" "$1"; exit 1;;
    esac
done

# Check if input variable exists
if  [ "${BIDSDir}" == "" ] || [ "${SubjectDir}" == "" ]; then
    Usage;
fi
if [[ ! -d ${SubjectDir} ]]; then
    echo "${SubjectDir} does not exist ... creating"
    mkdir -p ${SubjectDir}
fi
if [[ ! -d ${BIDSDir} ]]; then
    echo "Error: ${BIDSDir} "
    echo "       does not exist. Check that this value is correct."
    echo ""
    exit 1
fi


CalElapsedTime(){ #STARTTIME #mainlog.txt
    ENDTIME=$(date +"%s")
    duration=$(($ENDTIME - $1))
    echo "-------------$(date +"%Y-%m-%d %T") ## $((duration / 60)):$((duration % 60))\n" >> $2
}


pinfo="\n"
pinfo+="[Diffusion data processing pipeline] v${Version} ${VDate}\n"
pinfo+="Start process at $(date +"%Y-%m-%d %T")\n"
pinfo+="Subject ProcDir: ${SubjectDir}\n"
pinfo+="---------------------------------------------------------\n"
pinfo+="processing steps: ${Step}\n"
pinfo+="Bzero threshold: ${bzero}\n"
pinfo+="AtlasDir=${AtlasDir}\n"
pinfo+="trkNum=${trkNum}\n"
pinfo+="\n"

echo -e $pinfo
echo -e $pinfo >> ${SubjectDir}/mainlog.txt


for (( i = 0; i < ${#runStep[@]}; i++ )); do
    #statements
    case ${runStep[i]} in
        1 )
            # Step 1_DWIprep
            STARTTIME=$(date +"%s")
            echo "1_DWIprep at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
            sh ${HOGIO}/1_DWIprep.sh -b $BIDSDir -p $SubjectDir
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        2 )
            # Step 2_BiasCo
            STARTTIME=$(date +"%s")
            echo "2_BiasCo at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
            sh ${HOGIO}/2_BiasCo.sh -p $SubjectDir ${step2Arg}
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        3 )
            # Step 3_EddyCo
            STARTTIME=$(date +"%s")
            echo "3_EddyCo at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
            sh ${HOGIO}/3_EddyCo.sh -p $SubjectDir ${step3Arg}
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        4 )
            # Step 4_T1preproc
            STARTTIME=$(date +"%s")
            echo "4_T1preproc at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
            sh ${HOGIO}/4_T1preproc.sh -p $SubjectDir ${step4Arg}
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        5)
            # Step 5_DTIFIT
            STARTTIME=$(date +"%s")
            echo "5_DTIFIT at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
            sh ${HOGIO}/5_DTIFIT.sh -p $SubjectDir ${step5Arg}
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        6 )
            # Step 6_CSDpreproc
            STARTTIME=$(date +"%s")
            echo "6_CSDpreproc at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
            sh ${HOGIO}/6_CSDpreproc.sh -p $SubjectDir ${step6Arg}
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
        7 )
            # Step 7_NetworkProc
            STARTTIME=$(date +"%s")
            echo "7_NetworkProc at $(date +"%Y-%m-%d %T")" >> ${SubjectDir}/mainlog.txt
            sh ${HOGIO}/7_NetworkProc.sh -p $SubjectDir ${step7Arg}
            CalElapsedTime $STARTTIME ${SubjectDir}/mainlog.txt
            ;;
    esac
done

pinfo="End process at $(date +"%Y-%m-%d %T")"
echo $pinfo
echo $pinfo >> ${SubjectDir}/mainlog.txt
echo ""
