#---- Atlas Registration 
## pre/ () test to give full path in configure files
## need to save configure file(T1_2_ICBM_MNI152_1mm.cnf) to /usr/local/fsl/etc/flirtsch
## need to save MNI template (mni_icbm152_t1_tal_nlin_asym_09c/bet/mask) to /usr/local/fsl/data/standard

AtlasDir=/Users/heather/Documents/test_diffusionPipeline/Atlas
SubjectsDir=/Users/heather/Documents/test_diffusionPipeline/Analyzed/

cd ${SubjectsDir}
for subj in *; do
	cd ${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc
	mkdir ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network
	#T1 doing bet and fast
	mkdir ${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/T1_BET
	bet sub_${subj}_T1.nii.gz sub_${subj}_T1_bet -R -f 0.3 -g 0 -m
	fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -g -B -b -p -o ./T1_BET/sub_${subj}_T1_bet_Corrected sub_${subj}_T1_bet.nii.gz

	#registration 
	mkdir ${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix
	flirt -ref -in -ref ${AtlasDir}/MNI/mni_icbm152_t1_tal_nlin_asym_09c_bet.nii.gz -in ${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/T1_BET/sub_${subj}_T1_bet_Corrected_restore.nii.gz -omat ${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/str2mni_affine_transf.mat

	fnirt --ref=${AtlasDir}/MNI/mni_icbm152_t1_tal_nlin_asym_09c.nii.gz --in=${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/sub-${subj}_T1.nii.gz --aff=${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/str2mni_affine_transf.mat --cout=${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/str2mni_nonlinear_transf --config=T1_2_ICBM_MNI152_1mm

	invwarp --ref=${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/T1_BET/T1_bet_Corrected_restore.nii.gz --warp=${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/str2mni_nonlinear_transf.nii.gz --out=${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/mni2str_nonlinear_transf.nii.gz

	#Applywarp into DWI space
	mkdir ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/Atlas

	for i in HCPMMP DK AAL3 Yeo400; do 
		applywarp --ref=${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/T1_BET/T1_bet_Corrected_restore.nii.gz --in=${AtlasDir}/Atlas/${i}_resample.nii.gz --warp=${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/mni2str_nonlinear_transf.nii.gz --rel --out=${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/Atlas/sub_${subj}_${i}_inT1.nii.gz --interp=nn

		mrtransform ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/Atlas/sub_${subj}_${i}_inT1.nii.gz ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/Atlas/sub_${subj}_${i}_inDWI.nii.gz -linear ${SubjectsDir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_mrtrix.txt -interp nearest
	done

	#Relabel DK atlas
	labelconvert ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/Atlas/sub_${subj}_DK_inDWI.nii.gz ${AtlasDir}/colorlabel/FreeSurferColorLUT_DK.txt ${AtlasDir}/colorlabel/fs_default_DK.txt ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/Atlas/sub_${subj}_DK_inDWI.nii.gz -force

done