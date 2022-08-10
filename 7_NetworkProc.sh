#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Heather Hsu
## Version 2.0 /2020/02/08
## 20210208 replace matlab with python3 (argparse,pandas)
## 20210423 using ANTs to replace FSL(fnirt)
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##---- Atlas Registration
## pre/ () test to give full path in configure files
## Have to set AtlasDir with -a option (need to include Atlas/MNI directories)
## change select number as 10M
##########################################################################################################################

Usage(){
    cat <<EOF

7_NetworkProc - please setting the AtlasDir first
                6_CSDpreproc is needed before processing this script.
                This step will generate the track file based on the ODF in "6_CSDpreproc.""
                4_T1preproc is needed for generating connectivity matrix
                Connectivity matrix will be generate with four atlases (AAL3, HCPMMP w/o Subcortical regions, Yeo400)
                7_NetworkProc/Connectivity_Matrix will be created

Usage:  7_NetworkProc -[options]

System will automatically detect all folders in directory if no input arguments supplied
Default needed files could be downloaded from 120.126.40.109 with dpgroup/2020dpg

Options:
    -n  Select track number; [default = 1OM] (Please be aware of storage apace ~around 4G per person)
    -p  Input directory; [default = pwd directory]
    -a  Input Atlas directory; [default = need to include Atlas/MNI directories
EOF
exit 1
}


# Setup default variables
#Replace pwd to iDIO_HOME
#setting iDIO_HOME DIR

AtlasDir=${iDIO_HOME}/share
OriDir=$(pwd)
tckNum=10M
run_script=y
args="$(sed -E 's/(-[A-Za-z]+ )([^-]*)( |$)/\1"\2"\3/g' <<< $@)"
declare -a a="($args)"
set - "${a[@]}"

arg=-1

# Parse options
while getopts "hp:a:n:" optionName;
do
    #echo "-$optionName is present [$OPTARG]"
    case $optionName in
    h)
        Usage
        ;;
    p)
        OriDir=$OPTARG
        ;;
    a)
        AtlasDir=$OPTARG
        ;;
    n)
        tckNum=$OPTARG
        ;;
    \?)
        exit 42
        ;;
    *)
        echo "Unrecognised option $1" 1>&2
        exit 1
        ;;
    esac
done

# Check if previous step was done
if [ ! -d "${OriDir}/6_CSDpreproc" ]; then
    echo ""
    echo "Error: 6_CSDpreproc is not detected."
    echo "Please process previous step..."
    exit 1
fi

if [ ! -d "${OriDir}/4_T1preproc" ]; then
    echo ""
    echo "Error: 4_T1preproc is not detected."
    echo "Please process previous step..."
    exit 1
fi

if [ -f "`find ${OriDir}/Preprocessed_data -maxdepth 1 -name "T1w_mask_inDWIspace.nii.gz"`" ]; then
    handleMask=T1w_mask_inDWIspace.nii.gz
else
    echo ""
    echo "No Mask image found..."
    exit 1
fi

if [ -d ${OriDir}/7_NetworkProc ]; then
    echo ""
    echo "7_NetworkProc was detected,"
    echo "press y or wait for 10 seconds to continue,"
    echo "press n to terminate the program..."
    read -t 10 -p "y/n : " run_script
    if [ -z "$run_script" ]; then
        run_script=y
    fi
fi
if [ $run_script == "n" ]; then
    echo "System terminated"
    exit 1
fi
if [ $run_script != "y" ]; then
    echo ""
    echo "Error: Input is not valid..."
    exit 1
fi


[ -d ${OriDir}/7_NetworkProc ] || mkdir ${OriDir}/7_NetworkProc

mkdir ${OriDir}/7_NetworkProc/Reg_matrix
cd ${OriDir}/7_NetworkProc
#---- generate Track
echo Generating track
if [[ -f ${OriDir}/6_CSDpreproc/S1_Response/odf_wm_norm.mif ]]; then
    tckgen ${OriDir}/6_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/7_NetworkProc/Track_DynamicSeed_${tckNum}.tck -act ${OriDir}/4_T1preproc/5tt2dwispace.nii.gz -backtrack -crop_at_gmwmi -seed_dynamic ${OriDir}/6_CSDpreproc/S1_Response/odf_wm_norm.mif -maxlength 250 -minlength 5 -mask ${OriDir}/Preprocessed_data/${handleMask} -select ${tckNum} -quiet

    tcksift2 ${OriDir}/7_NetworkProc/Track_DynamicSeed_${tckNum}.tck ${OriDir}/6_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/7_NetworkProc/SIFT2_weights.txt -act ${OriDir}/4_T1preproc/5tt2dwispace.nii.gz -out_mu ${OriDir}/7_NetworkProc/SIFT_mu.txt -quiet
else
    tckgen ${OriDir}/6_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/7_NetworkProc/Track_DynamicSeed_${tckNum}.tck -act ${OriDir}/4_T1preproc/5tt2dwispace.nii.gz -backtrack -crop_at_gmwmi -seed_dynamic ${OriDir}/6_CSDpreproc/S1_Response/odf_wm.mif -maxlength 250 -minlength 5 -mask ${OriDir}/Preprocessed_data/${handleMask} -select ${tckNum} -quiet

    tcksift2 ${OriDir}/7_NetworkProc/Track_DynamicSeed_${tckNum}.tck ${OriDir}/6_CSDpreproc/S1_Response/odf_wm.mif ${OriDir}/7_NetworkProc/SIFT2_weights.txt -act ${OriDir}/4_T1preproc/5tt2dwispace.nii.gz -out_mu ${OriDir}/7_NetworkProc/SIFT_mu.txt -quiet
fi

# ----- Registration to MNI and generate native space atlas
echo Registrating to MNI atlas
antsRegistrationSyNQuick.sh -d 3 -f ${AtlasDir}/MNI/mni_icbm152_t1_tal_nlin_asym_09c_bet.nii.gz -m ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-Brain.nii.gz -o ${OriDir}/7_NetworkProc/Reg_matrix/T12MNI_

[ -d ${OriDir}/Connectivity_Matrix ] || mkdir ${OriDir}/Connectivity_Matrix

mkdir ${OriDir}/Connectivity_Matrix/Atlas
mkdir ${OriDir}/Connectivity_Matrix/Assignment

#------ Register Atlas to Native space
cd ${AtlasDir}/Atlas
mkdir ${OriDir}/Connectivity_Matrix/Mat_SIFT2Wei
mkdir ${OriDir}/Connectivity_Matrix/Mat_Length
mkdir ${OriDir}/Connectivity_Matrix/Mat_ScaleMu

echo Reconstructing connectome

for i in *; do
    AtName=$(echo ${i}|cut -f1 -d'_')
    WarpImageMultiTransform 3 ${AtlasDir}/Atlas/${i} ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inT1.nii.gz -R ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-Brain.nii.gz -i ${OriDir}/7_NetworkProc/Reg_matrix/T12MNI_0GenericAffine.mat ${OriDir}/7_NetworkProc/Reg_matrix/T12MNI_1InverseWarp.nii.gz --use-NN

    mrtransform ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inT1.nii.gz ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz -linear ${OriDir}/4_T1preproc/Reg_matrix/str2epi.txt -interp nearest
    # ----- Network reconstruction
    ## SIFT2-weighted connectome
    tck2connectome ${OriDir}/7_NetworkProc/Track_DynamicSeed_${tckNum}.tck ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz ${OriDir}/Connectivity_Matrix/Mat_SIFT2Wei/${AtName}_SIFT2.csv -tck_weights_in ${OriDir}/7_NetworkProc/SIFT2_weights.txt -symmetric -zero_diagonal -out_assignments ${OriDir}/Connectivity_Matrix/Assignment/${AtName}_Assignments.csv

    ## streamline length connectome
    tck2connectome ${OriDir}/7_NetworkProc/Track_DynamicSeed_${tckNum}.tck ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz ${OriDir}/Connectivity_Matrix/Mat_Length/${AtName}_Length.csv -symmetric -zero_diagonal -scale_length -stat_edge mean
done

for i in *; do
    AtName=$(echo ${i}|cut -f1 -d'_')
    python3 ${iDIO_HOME}/python/scale_mu.py ${OriDir}/Connectivity_Matrix/Mat_SIFT2Wei/${AtName}_SIFT2.csv ${OriDir}/7_NetworkProc/SIFT_mu.txt ${OriDir}/Connectivity_Matrix/Mat_ScaleMu/${AtName}_ScaleMu.csv
done
