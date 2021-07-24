#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Heather Hsu
## Version 1.0 /2020/07/20
## 20210720 Independent processing step for T1 (Proprocessing+Registration)
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##---- Atlas Registration
## pre/ () test to give full path in configure files
## Have to set AtlasDir with -a option (need to include Atlas/MNI directories)
##########################################################################################################################

Usage(){
    cat <<EOF

4_T1preproc - please set the AtlasDir first
                T1 processing will be included in this step. output file will save in "Preprocessed_data" file
                Although it is a T1 preprocessing step, preprocessed DWI images (saved in Preprocessed_data is needed for registration, resized image will be utilized if exists)

Usage:  4_T1preproc -[options]

System will automatically detect all folders in directory if no input arguments supplied
Default needed files could be downloaded from 120.126.40.109 with dpgroup/2020dpg

Options:
    -p  Input directory; [default = pwd directory]
    -a  Input Atlas directory; [default = need to include Atlas/MNI directories]
EOF
exit 1
}

AtlasDir=${HOGIO}/share
OriDir=$(pwd)
run_script=y
args="$(sed -E 's/(-[A-Za-z]+ )([^-]*)( |$)/\1"\2"\3/g' <<< $@)"
declare -a a="($args)"
set - "${a[@]}"
arg=-1

# Parse options
while getopts "hp:a:" optionName;
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
if [ ! -d "${OriDir}/3_EddyCo" ]; then
    echo ""
    echo "Error: 3_EddyCo is not detected."
    echo "Please process previous step..."
    exit 1
fi

# Subject ID
subjid=$(basename ${OriDir})

# Check if T1 file exists
if [ -f "`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*T1w.nii.gz"`" ]; then
    handleT1=${OriDir}/0_BIDS_NIFTI/*T1w.nii.gz
else
    echo ""
    echo "No T1 image found..."
    exit 1
fi

# Check preprocessing records
if [ -d ${OriDir}/4_T1preproc ]; then
    echo ""
    echo "4_T1preproc was detected,"
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

# make processing directory
[ -d ${OriDir}/4_T1preproc ] || mkdir ${OriDir}/4_T1preproc
[ -d ${OriDir}/Preprocessed_data ] || mkdir ${OriDir}/Preprocessed_data

# T1 preprocessing - for anatomical constrained tractography and atlas registration

mkdir -p ${OriDir}/4_T1preproc/Reg_matrix
cp ${handleT1} ${OriDir}/4_T1preproc/T1w.nii.gz
cd ${OriDir}/4_T1preproc
echo T1 preprocessing

# degibbs
mrdegibbs T1w.nii.gz T1w-deGibbs.nii.gz -quiet

# Ants N4 bias correction
N4BiasFieldCorrection -d 3 -v 0 -s 4 -b [180] -c [50x50x50, 0.0 ] -i T1w-deGibbs.nii.gz -o [T1w-deGibbs-BiasCo.nii.gz, T1w_BiasField.nii.gz ]

#Ants brain extraction (using OASIS prior)
if [ ! -e ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-Brain.nii.gz ]; then
    echo "Running Brain Extraction with antsBrainExtraction"
    antsBrainExtraction.sh -d 3 -a T1w-deGibbs-BiasCo.nii.gz -e ${AtlasDir}/MNI/MICCAI2012/T_template0.nii.gz -m ${AtlasDir}/MNI/MICCAI2012/T_template0_BrainCerebellumProbabilityMask.nii.gz -f ${AtlasDir}/MNI/MICCAI2012/T_template0_BrainCerebellumRegistrationMask.nii.gz -o T1w-deGibbs-BiasCo-
    rm -r ./T1w-deGibbs-BiasCo-
    mv ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-BrainExtractionBrain.nii.gz ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-Brain.nii.gz
    mv ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-BrainExtractionMask.nii.gz ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-Mask.nii.gz
    mv ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-BrainExtractionPrior0GenericAffine.mat ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-Prior0GenericAffine.mat
else
    echo "Brain Mask Found: antsBrainExtraction Skipped"
fi

# using 5tt seg to replace bet and fast, and save the scratch file
5ttgen fsl -nocrop -sgm_amyg_hipp T1w-deGibbs-BiasCo-Brain.nii.gz 5tt.nii.gz -nocleanup -premasked -scratch ./T1tmp/ -quiet

cp ${OriDir}/4_T1preproc/T1tmp/T1_pve*.nii.gz ${OriDir}/4_T1preproc
rm -r ./T1tmp

for i in T1_pve*;do
    mv ${i} T1w-deGibbs-BiasCo-Brain_pve${i:6}
done

#extract WMseg for bbr
fslmaths T1w-deGibbs-BiasCo-Brain_pveseg.nii.gz -thr 3 -bin WMseg.nii.gz

# Check DWI (default: Using resized processed.nii.gz in the Processed_data directory )
handle=dwi_preprocessed_resized
if [[ -f ${OriDir}/Preprocessed_data/${handle}.nii.gz ]] && [[ -f ${OriDir}/Preprocessed_data/${handle}.bval ]] && [[ -f ${OriDir}/Preprocessed_data/${handle}.bvec ]]; then
    :
elif [[ ! -f ${OriDir}/Preprocessed_data/${handle}.nii.gz ]] && [[ -f ${OriDir}/Preprocessed_data/dwi_preprocessed.nii.gz ]] ; then
    handle=dwi_preprocessed
else
        echo ""
        echo "No preprocessed dwi image found..."
        exit 1
fi

cp ${OriDir}/Preprocessed_data/dwi_preprocessed-Average_b0-brain.nii.gz ${OriDir}/4_T1preproc/Average_b0-brain.nii.gz

# bbr-linear registration of B0 to T1
echo Registrting DWI to T1

flirt -in ${OriDir}/4_T1preproc/Average_b0-brain.nii.gz -ref T1w-deGibbs-BiasCo-Brain.nii.gz -dof 6 -cost corratio -omat ${OriDir}/4_T1preproc/Reg_matrix/epi2str_init.mat
flirt -ref ./T1w-deGibbs-BiasCo.nii.gz -in ${OriDir}/4_T1preproc/Average_b0-brain.nii.gz -dof 6 -cost bbr -wmseg ./WMseg.nii.gz -init ${OriDir}/4_T1preproc/Reg_matrix/epi2str_init.mat -omat ${OriDir}/4_T1preproc/Reg_matrix/epi2str.mat -schedule ${FSLDIR}/etc/flirtsch/bbr.sch
convert_xfm ${OriDir}/4_T1preproc/Reg_matrix/epi2str.mat -omat ${OriDir}/4_T1preproc/Reg_matrix/str2epi.mat -inverse

#convert tranformation matrix in to mrtrix format

transformconvert ${OriDir}/4_T1preproc/Reg_matrix/str2epi.mat ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-Brain.nii.gz ${OriDir}/4_T1preproc/Average_b0-brain.nii.gz flirt_import ${OriDir}/4_T1preproc/Reg_matrix/str2epi.txt
mrtransform 5tt.nii.gz ${OriDir}/4_T1preproc/5tt2dwispace.nii.gz -linear ${OriDir}/4_T1preproc/Reg_matrix/str2epi.txt

# convert T1brain masks to DWI space
flirt -in ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-Mask.nii.gz -ref ${OriDir}/4_T1preproc/Average_b0-brain.nii.gz -out ${OriDir}/4_T1preproc/T1maskindwispace.nii.gz -init ${OriDir}/4_T1preproc/Reg_matrix/str2epi.mat -applyxfm -interp nearestneighbour


# Warning for negative b-values and make T1 negative value to 0
tmpv=$(fslstats ${OriDir}/4_T1preproc/Average_b0-brain.nii.gz -u 0 -v |awk {'print $1'})
tput setaf 1 # change terminal color to red color
echo "Warning: ${tmpv} negative voxels in Average_b0"
tput sgr0 # change terminal color to default color
# echo -e "\033[1;31mWarning: ${tmpv} negative voxels in Average_b0 \033[0m"
tmpv=$(fslstats ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo.nii.gz -u 0 -v |awk {'print $1'})
tput setaf 1 # change terminal color to red color
echo "Warning: ${tmpv} negative voxels in T1w-deGibbs-BiasCo.nii.gz and have been replaced with 0 into T1w_preprocessed.nii.gz"
tput sgr0 
# echo -e "\033[1;31mWarning: ${tmpv} negative voxels in T1w-deGibbs-BiasCo.nii.gz and have been replaced with 0 into T1w_preprocessed.nii.gz \033[0m"

fslmaths ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo.nii.gz -thr 0 ${OriDir}/4_T1preproc/T1w_preprocessed.nii.gz
cp ${OriDir}/4_T1preproc/T1w_preprocessed.nii.gz ${OriDir}/Preprocessed_data/T1w_preprocessed.nii.gz
cp ${OriDir}/4_T1preproc/T1w-deGibbs-BiasCo-Mask.nii.gz ${OriDir}/Preprocessed_data/T1w_mask.nii.gz
cp ${OriDir}/4_T1preproc/T1maskindwispace.nii.gz ${OriDir}/Preprocessed_data/T1w_mask_inDWIspace.nii.gz