#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Heather Hsu
## Version 1.0 /2020/02/05
##
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##---- Atlas Registration 							
## pre/ () test to give full path in configure files
## need to save configure file(T1_2_ICBM_MNI152_1mm.cnf) to /usr/local/fsl/etc/flirtsch
## need to save MNI template (mni_icbm152_t1_tal_nlin_asym_09c_/bet/mask.nii.gz) to /usr/local/fsl/data/standard
##
## Have to set AtlasDir with -a option (need to include Atlas/MNI directories)
## 
##########################################################################################################################

Usage(){
	cat <<EOF

6_NetworkProc - 5_CSDpreproc and the track.tck files are needed before processing this script.
			  - please setting the AtlasDir first
			  - 6_NetworkProc will be created

Usage:	6_NetworkProc -[options] 

System will automatically detect all folders in directory if no input arguments supplied
need to save configure file(T1_2_ICBM_MNI152_1mm.cnf) to /usr/local/fsl/etc/flirtsch
need to save MNI template (mni_icbm152_t1_tal_nlin_asym_09c_/bet/mask.nii.gz) to /usr/local/fsl/data/standard
Default needed files could be downloaded from 120.126.40.109 with dpgroup/2020dpg

Options:
	-p 	Input directory; [default = pwd directory]
	-a 	Input Atlas directory; [default = pwd/configure_Atlas, need to include Atlas/MNI directories

EOF
exit 1
}



# Setup default variables
#Replace pwd to HOMEDI
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

# Check if configure file, default atlas exist
if [[ ! -f "/usr/local/fsl/etc/flirtsch/T1_2_ICBM_MNI152_1mm.cnf" ]] || 
   [[ ! -f "/usr/local/fsl/data/standard/mni_icbm152_t1_tal_nlin_asym_09c.nii.gz" ]] || 
   [[ ! -f "/usr/local/fsl/data/standard/mni_icbm152_t1_tal_nlin_asym_09c_bet.nii.gz" ]] || 
   [[ ! -f "/usr/local/fsl/data/standard/mni_icbm152_t1_tal_nlin_asym_09c_mask.nii.gz" ]]; then	
	echo ""
	echo "No configure file or default atlas found..."
	Usage
fi


# Check if previous step was done
if [ ! -d "${OriDir}/5_CSDpreproc" ]; then
	echo ""
	echo "Error: 5_CSDpreproc is not detected."
	echo "Please process previous step..."
	exit 1
fi

if [ -f "`find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*T1w.nii.gz"`" ]; then
	handleT1=${OriDir}/0_BIDS_NIFTI/*T1w.nii.gz
	T1name=$(basename -- $(find ${OriDir}/0_BIDS_NIFTI -maxdepth 1 -name "*T1w.nii.gz") | cut -f1 -d '.')
else
	echo ""
	echo "No Preprocessed T1 image found..."
	exit 1
fi

subjid=$(basename ${OriDir})
if [ -f "`find ${OriDir}/4_DTIFIT -maxdepth 1 -name "*Average_b0.nii.gz"`" ]; then
	handleMask=${OriDir}/4_DTIFIT/*b0-brain_mask.nii.gz
else
	echo ""
	echo "No Preprocessed B0-Mask image found..."
	exit 1
fi

#S4 generate Track
mkdir ${OriDir}/5_CSDpreproc/S3_Tractography
tckgen ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S3_Tractography/track_DynamicSeed_1M.tck -act ${OriDir}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -backtrack -crop_at_gmwmi -seed_dynamic ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif -maxlength 250 -minlength 5 -mask ${handleMask} -select 1M

tcksift2 ${OriDir}/5_CSDpreproc/S3_Tractography/track_DynamicSeed_1M.tck ${OriDir}/5_CSDpreproc/S2_Response/odf_wm.mif ${OriDir}/5_CSDpreproc/S3_Tractography/SIFT2_weights.txt -act ${OriDir}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -out_mu ${OriDir}/5_CSDpreproc/S3_Tractography/SIFT_mu.txt

cd ${OriDir}/5_CSDpreproc/S1_T1proc
#T1 doing bet and fast
mkdir ${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET
cp ${handleT1} ${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET
bet ${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET/${T1name}.nii.gz ${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET/${T1name}_bet.nii.gz -R -f 0.3 -g 0 -m
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -g -B -b -p -o ${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET/${T1name}_bet_Corrected ${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET/${T1name}_bet.nii.gz
#registration 
# mkdir ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix
flirt -ref ${AtlasDir}/MNI/mni_icbm152_t1_tal_nlin_asym_09c_bet.nii.gz -in ${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET/${T1name}_bet_Corrected_restore.nii.gz -omat ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/str2mni_affine_transf.mat

fnirt --ref=${AtlasDir}/MNI/mni_icbm152_t1_tal_nlin_asym_09c.nii.gz --in=${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET/${T1name}.nii.gz --aff=${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/str2mni_affine_transf.mat --cout=${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/str2mni_nonlinear_transf --config=T1_2_ICBM_MNI152_1mm

invwarp --ref=${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET/${T1name}_bet_Corrected_restore.nii.gz --warp=${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/str2mni_nonlinear_transf.nii.gz --out=${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/mni2str_nonlinear_transf.nii.gz


#Applywarp into DWI space
if [ -d ${OriDir}/6_NetworkProc ]; then
	echo ""
	echo "6_NetworkProc was detected,"
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

[ -d ${OriDir}/6_NetworkProc ] || mkdir ${OriDir}/6_NetworkProc

mkdir ${OriDir}/6_NetworkProc/Atlas
cd ${AtlasDir}/Atlas
for i in *; do 
	applywarp --ref=${OriDir}/5_CSDpreproc/S1_T1proc/T1_BET/${T1name}_bet_Corrected_restore.nii.gz --in=${AtlasDir}/Atlas/${i} --warp=${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/mni2str_nonlinear_transf.nii.gz --rel --out=${OriDir}/6_NetworkProc/Atlas/${subjid}_${i%%.*}_inT1.nii.gz --interp=nn

	mrtransform ${OriDir}/6_NetworkProc/Atlas/${subjid}_${i%%.*}_inT1.nii.gz ${OriDir}/6_NetworkProc/Atlas/${subjid}_${i%%.*}_inDWI.nii.gz -linear ${OriDir}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_mrtrix.txt -interp nearest
	if [[ ${i} == "DK_resample_ICBM.nii.gz" ]]; then
		#Relabel DK atlas
		labelconvert ${OriDir}/6_NetworkProc/Atlas/${subjid}_${i%%.*}_inDWI.nii.gz ${AtlasDir}/colorlabel/FreeSurferColorLUT_DK.txt ${AtlasDir}/colorlabel/fs_default_DK.txt ${OriDir}/6_NetworkProc/Atlas/${subjid}_${i%%.*}_inDWI.nii.gz -force
	fi
done



# ---- Network reconstruction 
# Check needed file
if [ -f "`find ${OriDir}/5_CSDpreproc/S3_Tractography -maxdepth 1 -name "*1M.tck"`" ]; then
	tckname=$(basename -- $(find ${OriDir}/5_CSDpreproc/S3_Tractography -maxdepth 1 -name "*1M.tck") | cut -f1 -d '.')
	handletck=${OriDir}/5_CSDpreproc/S3_Tractography/${tckname}

else
	echo ""
	echo "No tck image found..."
	exit 1
fi
for i in *; do 
## SIFT2-weighted connectome
tck2connectome ${OriDir}/5_CSDpreproc/S3_Tractography/${tckname}.tck ${OriDir}/6_NetworkProc/Atlas/${subjid}_${i%%.*}_inDWI.nii.gz ${OriDir}/6_NetworkProc/${subjid}_connectome_${i%%.*}.csv -tck_weights_in ${OriDir}/5_CSDpreproc/S3_Tractography/SIFT2_weights.txt -symmetric -zero_diagonal -out_assignments ${OriDir}/6_NetworkProc/${subjid}_${i%%.*}_Assignments.csv  -assignment_radial_search 2

## need to scale the SIFT2-weighted connectome by mu 
## SIFT2-weighted connectome with node volumes 
## Q: SIFT2+normalized by volumes?
tck2connectome ${OriDir}/5_CSDpreproc/S3_Tractography/${tckname}.tck ${OriDir}/6_NetworkProc/Atlas/${subjid}_${i%%.*}_inDWI.nii.gz ${OriDir}/6_NetworkProc/${subjid}_connectome_${i%%.*}_scalenodevol.csv -tck_weights_in ${OriDir}/5_CSDpreproc/S3_Tractography/SIFT2_weights.txt -symmetric -zero_diagonal -assignment_radial_search 2 -scale_invnodevol
done
echo "SIFT-weighted connectome have to be scaled by mu"

