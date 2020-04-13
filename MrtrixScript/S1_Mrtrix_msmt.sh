Process_Dir='/Users/heather/Documents/test_diffusionPipeline/Analyzed'
cd ${Process_Dir}
for subj in *; do
	#S1 generate 5tt (lack: compare 5tt and freesurfer)
	mkdir ${Process_Dir}/${subj}/5_CSDpreproc
	mkdir ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc

	# 6 degree registration without resampling
	flirt -in ${Process_Dir}/${subj}/0_BIDS_NIFTI/sub-${subj}_T1.nii.gz -ref ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc-Average_b0.nii.gz -omat ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_flirt6.mat -dof 6
	
	transformconvert ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_flirt6.mat ${Process_Dir}/${subj}/0_BIDS_NIFTI/sub-${subj}_T1.nii.gz ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc-Average_b0.nii.gz flirt_import ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_mrtrix.txt
	
	mrtransform ${Process_Dir}/${subj}/0_BIDS_NIFTI/sub-${subj}_T1.nii.gz ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/T12dwispace.nii.gz -linear ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/Reg_matrix/T12DWI_mrtrix.txt
	
	5ttgen fsl -nocrop ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/T12dwispace.nii.gz ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -quiet
    
    5ttgen fsl -nocrop -sgm_amyg_hipp ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/T12dwispace.nii.gz ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/5tt2dwispace_sgm_amyg_hipp.nii.gz -quiet
	
	5tt2gmwmi ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/WMGM2dwispace.nii.gz -quiet

	# S2 CSDproproc
	mkdir ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response
	echo ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc.nii.gz
	mrconvert ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc.nii.gz ${Process_Dir}/${subj}/5_CSDpreproc/${subj}-preproc.mif -fslgrad ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc.bvec ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc.bval 

	dwibiascorrect -ants ${Process_Dir}/${subj}/5_CSDpreproc/${subj}-preproc.mif ${Process_Dir}/${subj}/5_CSDpreproc/${subj}-preproc-unbiased.mif

	dwi2response dhollander ${Process_Dir}/${subj}/5_CSDpreproc/${subj}-preproc-unbiased.mif ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/response_wm.txt ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/response_gm.txt ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/response_csf.txt 

	# S3 FBApreproc (upsampling)
	mrresize ${Process_Dir}/${subj}/5_CSDpreproc/${subj}-preproc-unbiased.mif -vox 1.3 ${Process_Dir}/${subj}/5_CSDpreproc/${subj}-preproc-unbiased_upsampled.mif
	
	dwi2mask ${Process_Dir}/${subj}/5_CSDpreproc/${subj}-preproc-unbiased_upsampled.mif ${Process_Dir}/${subj}/5_CSDpreproc/dwi_mask_upsampled.mif -fslgrad ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc.bvec ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc.bval 
	
	dwi2mask ${Process_Dir}/${subj}/5_CSDpreproc/${subj}-preproc-unbiased.mif ${Process_Dir}/${subj}/5_CSDpreproc/dwi_mask.mif -fslgrad ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc.bvec ${Process_Dir}/${subj}/4_DTIFIT/${subj}-preproc.bval 
	

	dwi2fod msmt_csd ${Process_Dir}/${subj}/5_CSDpreproc/${subj}-preproc-unbiased.mif ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/response_wm.txt ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/odf_wm.mif ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/response_gm.txt ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/odf_gm.mif ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/response_csf.txt ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/odf_csf.mif -mask ${Process_Dir}/${subj}/5_CSDpreproc/dwi_mask.mif

	#S4 generate Track
	mkdir ${Process_Dir}/${subj}/5_CSDpreproc/S3_Tractography
	tckgen ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/odf_wm.mif ${Process_Dir}/${subj}/5_CSDpreproc/S3_Tractography/track_DynamicSeed_1M.tck -act ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -backtrack -crop_at_gmwmi -seed_dynamic ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/odf_wm.mif -maxlength 250 -minlength 5 -mask ${Process_Dir}/${subj}/5_CSDpreproc/dwi_mask_upsampled.mif -select 1M
	
	tcksift2 ${Process_Dir}/${subj}/5_CSDpreproc/S3_Tractography/track_DynamicSeed_1M.tck ${Process_Dir}/${subj}/5_CSDpreproc/S2_Response/odf_wm.mif ${Process_Dir}/${subj}/5_CSDpreproc/S3_Tractography/SIFT2_weights.txt -act ${Process_Dir}/${subj}/5_CSDpreproc/S1_T1proc/5tt2dwispace.nii.gz -out_mu ${Process_Dir}/${subj}/5_CSDpreproc/S3_Tractography/SIFT_mu.txt

done