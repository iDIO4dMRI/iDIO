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

6_NetworkProc - please setting the AtlasDir first
                5_CSDpreproc is needed before processing this script.
                This step will generate the track file based on the ODF in "5_CSDpreproc.""
                T1 processing will also include in this step. output file will save in "Preprocessed_data" file
                Connectivity matrix will be generate with five atlases (AAL3, DK, HCPMMP w/o Subcortical regions, Yeo)
                6_Tractography/7_Network will be created

Usage:  6_NetworkProc -[options]

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
#Replace pwd to HOGIO
#setting HOGIO DIR

AtlasDir=${HOGIO}/share
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
if [ ! -d "${OriDir}/5_CSDpreproc" ]; then
    echo ""
    echo "Error: 5_CSDpreproc is not detected."
    echo "Please process previous step..."
    exit 1
fi

if [ -f "`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*T1w.nii.gz"`" ]; then
    handleT1=${OriDir}/0_BIDS_NIFTI/*T1w.nii.gz
    # T1name=$(basename -- $(find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*T1w.nii.gz") | cut -f1 -d '.')
else
    echo ""
    echo "No T1 image found..."
    exit 1
fi

# subjid=$(basename ${OriDir})
handleMask=${OriDir}/4_DTIFIT/*b0-brain_mask.nii.gz

#Applywarp into DWI space
if [ -d ${OriDir}/6_Tractography ]; then
    echo ""
    echo "6_Tractography was detected,"
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


[ -d ${OriDir}/6_Tractography ] || mkdir ${OriDir}/6_Tractography

# T1 preprocessing - for anatomical constrained tractography and atlas registration

mkdir -p ${OriDir}/6_Tractography/S1_T1proc
mkdir -p ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix
cp ${handleT1} ${OriDir}/6_Tractography/S1_T1proc/T1w.nii.gz

cd ${OriDir}/6_Tractography/S1_T1proc
echo T1 preprocessing

# degibbs
mrdegibbs T1w.nii.gz T1-deGibbs.nii.gz -quiet

# Ants N4 bias correction
N4BiasFieldCorrection -d 3 -v 0 -s 4 -b [180] -c [50x50x50, 0.0 ] -i T1-deGibbs.nii.gz -o [T1w-deGibbs-BiasCo.nii.gz, T1w_BiasField.nii.gz ]
cp ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo.nii.gz ${OriDir}/Preprocessed_data/T1w_preprocessed.nii.gz

# Ants brain extraction (using OASIS prior)
if [ ! -e ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-Brain.nii.gz ]; then
    echo "Running Brain Extraction with antsBrainExtraction"
    antsBrainExtraction.sh -d 3 -a T1w-deGibbs-BiasCo.nii.gz -e ${AtlasDir}/MNI/MICCAI2012/T_template0.nii.gz -m ${AtlasDir}/MNI/MICCAI2012/T_template0_BrainCerebellumProbabilityMask.nii.gz -f ${AtlasDir}/MNI/MICCAI2012/T_template0_BrainCerebellumRegistrationMask.nii.gz -o T1w-deGibbs-BiasCo-
    rm -r ./T1w-deGibbs-BiasCo-
    mv ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-BrainExtractionBrain.nii.gz ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-Brain.nii.gz
    mv ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-BrainExtractionMask.nii.gz ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-Mask.nii.gz
    mv ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-BrainExtractionPrior0GenericAffine.mat ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-Prior0GenericAffine.mat
else
    echo "Brain Mask Found: antsBrainExtraction Skipped"
fi

# using 5tt seg to replace bet and fast, and save the scratch file
5ttgen fsl -nocrop -sgm_amyg_hipp T1w-deGibbs-BiasCo-Brain.nii.gz 5tt.nii.gz -nocleanup -premasked -scratch ./T1tmp/ -quiet

cp ${OriDir}/6_Tractography/S1_T1proc/T1tmp/T1_pve*.nii.gz ${OriDir}/6_Tractography/S1_T1proc
rm -r ./T1tmp

for i in T1_pve*;do
    mv ${i} T1w-deGibbs-BiasCo-Brain_pve${i:6}
done

#extract WMseg for bbr
fslmaths T1w-deGibbs-BiasCo-Brain_pveseg.nii.gz -thr 3 -bin WMseg.nii.gz

cp ${OriDir}/4_DTIFIT/*Average_b0-brain.nii.gz ${OriDir}/6_Tractography/Average_b0-brain.nii.gz
cp ${OriDir}/4_DTIFIT/*Average_b0.nii.gz ${OriDir}/6_Tractography/Average_b0.nii.gz

# bbr-linear registration of B0 to T1
echo Registrting DWI to T1

flirt -in ${OriDir}/6_Tractography/Average_b0-brain.nii.gz -ref T1w-deGibbs-BiasCo-Brain.nii.gz -dof 6 -cost corratio -omat ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/epi2str_init.mat
flirt -ref ./T1w-deGibbs-BiasCo.nii.gz -in ${OriDir}/6_Tractography/Average_b0-brain.nii.gz -dof 6 -cost bbr -wmseg ./WMseg.nii.gz -init ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/epi2str_init.mat -omat ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/epi2str.mat -schedule ${FSLDIR}/etc/flirtsch/bbr.sch
convert_xfm ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/epi2str.mat -omat ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.mat -inverse

# convert to mrtrix format
transformconvert ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.mat ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-Brain.nii.gz ${OriDir}/6_Tractography/Average_b0-brain.nii.gz flirt_import ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.txt
mrtransform 5tt.nii.gz ${OriDir}/6_Tractography/5tt2dwispace.nii.gz -linear ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.txt

cd ${OriDir}/6_Tractography
#---- generate Track
echo Generating track
tckgen ${OriDir}/5_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/6_Tractography/Track_DynamicSeed_${tckNum}.tck -act ${OriDir}/6_Tractography/5tt2dwispace.nii.gz -backtrack -crop_at_gmwmi -seed_dynamic ${OriDir}/5_CSDpreproc/S1_Response/odf_wm_norm.mif -maxlength 250 -minlength 5 -mask ${handleMask} -select ${tckNum} -quiet

tcksift2 ${OriDir}/6_Tractography/Track_DynamicSeed_${tckNum}.tck ${OriDir}/5_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/6_Tractography/SIFT2_weights.txt -act ${OriDir}/6_Tractography/5tt2dwispace.nii.gz -out_mu ${OriDir}/6_Tractography/SIFT_mu.txt -quiet

# ----- Registration to MNI and generate native space atlas
echo Registrating to MNI atlas
antsRegistrationSyNQuick.sh -d 3 -f ${AtlasDir}/MNI/mni_icbm152_t1_tal_nlin_asym_09c_bet.nii.gz -m ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-Brain.nii.gz -o T12MNI_ 
mv T12MNI_* ${OriDir}/6_Tractography/S1_T1proc/

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
    WarpImageMultiTransform 3 ${AtlasDir}/Atlas/${i} ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inT1.nii.gz -R ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo-Brain.nii.gz -i ${OriDir}/6_Tractography/S1_T1proc/T12MNI_0GenericAffine.mat ${OriDir}/6_Tractography/S1_T1proc/T12MNI_1InverseWarp.nii.gz --use-NN 

    mrtransform ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inT1.nii.gz ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz -linear ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.txt -interp nearest
    # ----- Network reconstruction
    ## SIFT2-weighted connectome
    tck2connectome ${OriDir}/6_Tractography/Track_DynamicSeed_${tckNum}.tck ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz ${OriDir}/Connectivity_Matrix/Mat_SIFT2Wei/${AtName}_SIFT2.csv -tck_weights_in ${OriDir}/6_Tractography/SIFT2_weights.txt -symmetric -zero_diagonal -out_assignments ${OriDir}/Connectivity_Matrix/Assignment/${AtName}_Assignments.csv

    ## streamline length connectome
    tck2connectome ${OriDir}/6_Tractography/Track_DynamicSeed_${tckNum}.tck ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz ${OriDir}/Connectivity_Matrix/Mat_Length/${AtName}_Length.csv -symmetric -zero_diagonal -scale_length -stat_edge mean
done

for i in *; do
    AtName=$(echo ${i}|cut -f1 -d'_')
    python3 ${HOGIO}/python/scale_mu.py ${OriDir}/Connectivity_Matrix/Mat_SIFT2Wei/${AtName}_SIFT2.csv ${OriDir}/6_Tractography/SIFT_mu.txt ${OriDir}/Connectivity_Matrix/Mat_ScaleMu/${AtName}_ScaleMu.csv
done
