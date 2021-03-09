#!/bin/sh

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Heather Hsu
## Version 1.0 /2020/02/08
## 20210208 replace matlab with python3 (argparse,pandas)
##########################################################################################################################


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##---- Atlas Registration
## pre/ () test to give full path in configure files
## need to save configure file(T1_2_ICBM_MNI152_1mm.cnf) to /usr/local/fsl/etc/flirtsch
## need to save MNI template (mni_icbm152_t1_tal_nlin_asym_09c_/bet/mask.nii.gz) to /usr/local/fsl/data/standard
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

Usage:	6_NetworkProc -[options]

System will automatically detect all folders in directory if no input arguments supplied
need to save configure file(T1_2_ICBM_MNI152_1mm.cnf) to /usr/local/fsl/etc/flirtsch
need to save MNI template (mni_icbm152_t1_tal_nlin_asym_09c_/bet/mask.nii.gz) to /usr/local/fsl/data/standard
Default needed files could be downloaded from 120.126.40.109 with dpgroup/2020dpg

Options:
	-n  Select track number; [default = 1OM] (Please be aware of storage apace ~around 4G per person)
	-p 	Input directory; [default = pwd directory]
	-a 	Input Atlas directory; [default = need to include Atlas/MNI directories
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
	echo "No Preprocessed T1 image found..."
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

# using 5tt seg to replace bet and fast, and save the scratch file
5ttgen fsl -nocrop -sgm_amyg_hipp T1w-deGibbs-BiasCo.nii.gz 5tt.nii.gz -nocleanup -scratch ./T1tmp/ -quiet
# 5tt2gmwmi T1w_corrected.nii.gz WMGMi.nii.gz -quiet

cp ${OriDir}/6_Tractography/S1_T1proc/T1tmp/T1_BET.nii.gz ${OriDir}/6_Tractography/S1_T1proc
cp ${OriDir}/6_Tractography/S1_T1proc/T1tmp/T1_BET*.nii.gz ${OriDir}/6_Tractography/S1_T1proc
rm -r ./T1tmp

for i in T1_BET*;do
	mv ${i} T1w-deGibbs-BiasCo_BET${i:6}
done

#extract WMseg for bbr
fslmaths T1w-deGibbs-BiasCo_BET_pveseg.nii.gz -thr 3 -bin WMseg.nii.gz

cp ${OriDir}/4_DTIFIT/*Average_b0-brain.nii.gz ${OriDir}/6_Tractography/Average_b0-brain.nii.gz
cp ${OriDir}/4_DTIFIT/*Average_b0.nii.gz ${OriDir}/6_Tractography/Average_b0.nii.gz

# bbr-linear registration of B0 to T1
echo Registrting DWI to T1

flirt -in ${OriDir}/6_Tractography/Average_b0-brain.nii.gz -ref T1w-deGibbs-BiasCo_BET.nii.gz -dof 6 -cost corratio -omat ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/epi2str_init.mat
flirt -ref ./T1w-deGibbs-BiasCo.nii.gz -in ${OriDir}/6_Tractography/Average_b0-brain.nii.gz -dof 6 -cost bbr -wmseg ./WMseg.nii.gz -init ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/epi2str_init.mat -omat ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/epi2str.mat -schedule ${FSLDIR}/etc/flirtsch/bbr.sch
convert_xfm ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/epi2str.mat -omat ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.mat -inverse

# convert to mrtrix format
transformconvert ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.mat ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo_BET.nii.gz ${OriDir}/6_Tractography/Average_b0-brain.nii.gz flirt_import ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.txt
mrtransform 5tt.nii.gz ${OriDir}/6_Tractography/5tt2dwispace.nii.gz -linear ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.txt

cd ${OriDir}/6_Tractography
#---- generate Track
echo Generating track
tckgen ${OriDir}/5_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/6_Tractography/Track_DynamicSeed_${tckNum}.tck -act ${OriDir}/6_Tractography/5tt2dwispace.nii.gz -backtrack -crop_at_gmwmi -seed_dynamic ${OriDir}/5_CSDpreproc/S1_Response/odf_wm_norm.mif -maxlength 250 -minlength 5 -mask ${handleMask} -select ${tckNum} -quiet

tcksift2 ${OriDir}/6_Tractography/Track_DynamicSeed_${tckNum}.tck ${OriDir}/5_CSDpreproc/S1_Response/odf_wm_norm.mif ${OriDir}/6_Tractography/SIFT2_weights.txt -act ${OriDir}/6_Tractography/5tt2dwispace.nii.gz -out_mu ${OriDir}/6_Tractography/SIFT_mu.txt -quiet

# ----- Registration to MNI and generate native space atlas
echo Registrating to MNI atlas
flirt -ref ${AtlasDir}/MNI/mni_icbm152_t1_tal_nlin_asym_09c_bet.nii.gz -in ${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo_BET.nii.gz -omat ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2mni_affine_transf.mat

fnirt --ref=${AtlasDir}/MNI/mni_icbm152_t1_tal_nlin_asym_09c.nii.gz --in=${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo.nii.gz --aff=${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2mni_affine_transf.mat --cout=${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2mni_nonlinear_transf --config=T1_2_ICBM_MNI152_1mm

invwarp --ref=${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo_BET.nii.gz --warp=${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2mni_nonlinear_transf.nii.gz --out=${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/mni2str_nonlinear_transf.nii.gz


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
	applywarp --ref=${OriDir}/6_Tractography/S1_T1proc/T1w-deGibbs-BiasCo_BET.nii.gz --in=${AtlasDir}/Atlas/${i} --warp=${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/mni2str_nonlinear_transf.nii.gz --rel --out=${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inT1.nii.gz --interp=nn

	mrtransform ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inT1.nii.gz ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz -linear ${OriDir}/6_Tractography/S1_T1proc/Reg_matrix/str2epi.txt -interp nearest
	if [[ ${i} == "DK_resample_ICBM.nii.gz" ]]; then
		#Relabel DK atlas
		labelconvert ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz ${AtlasDir}/colorlabel/FreeSurferColorLUT_DK.txt ${AtlasDir}/colorlabel/fs_default_DK.txt ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz -force
	fi
	# ----- Network reconstruction
	## SIFT2-weighted connectome
	tck2connectome ${OriDir}/6_Tractography/Track_DynamicSeed_${tckNum}.tck ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz ${OriDir}/Connectivity_Matrix/Mat_SIFT2Wei/${AtName}_SIFT2.csv -tck_weights_in ${OriDir}/6_Tractography/SIFT2_weights.txt -symmetric -zero_diagonal -out_assignments ${OriDir}/Connectivity_Matrix/Assignment/${AtName}_Assignments.csv

	## streamline length connectome
	tck2connectome ${OriDir}/6_Tractography/Track_DynamicSeed_${tckNum}.tck ${OriDir}/Connectivity_Matrix/Atlas/${AtName}_inDWI.nii.gz ${OriDir}/Connectivity_Matrix/Mat_Length/${AtName}_Length.csv -symmetric -zero_diagonal -scale_length -stat_edge mean
done

for i in *;	do
	AtName=$(echo ${i}|cut -f1 -d'_')
	python3 ${HOGIO}/python/scale_mu.py ${OriDir}/Connectivity_Matrix/Mat_SIFT2Wei/${AtName}_SIFT2.csv ${OriDir}/6_Tractography/SIFT_mu.txt ${OriDir}/Connectivity_Matrix/Mat_ScaleMu/${AtName}_ScaleMu.csv
done
