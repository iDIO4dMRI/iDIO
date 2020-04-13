	# ---- Network reconstruction 
	SubjectsDir=/Users/heather/Documents/test_diffusionPipeline/Analyzed/

	for i in HCPMMP DK AAL3 Yeo400; do 
	## SIFT2-weighted connectome
	tck2connectome ${SubjectsDir}/${subj}/5_CSDpreproc/S3_Tractography/track_DynamicSeed_1M.tck ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/Atlas/sub_${subj}_${i}_inDWI.nii.gz ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/sub_${subj}_connectome_${i}.csv -tck_weights_in tck_weights.txt -symmetric -zero_diagonal -out_assignments ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/sub_${subj}_Assignments.csv  -assignment_radial_search 2

	## scale the SIFT2-weighted connectome by mu (using external tools, e.g. MATLAB) ## NEED TO MERGE INTO ONE SCRIPT

	## SIFT2-weighted connectome with node volumes #Q:whether have to use the tck_weights_in? does it works? SIFT2+normalized by volunes?
	tck2connectome ${SubjectsDir}/${subj}/5_CSDpreproc/S3_Tractography/track_DynamicSeed_1M.tck ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/Atlas/sub_${subj}_${i}_inDWI.nii.gz ${SubjectsDir}/${subj}/5_CSDpreproc/S4_Network/sub_${subj}_connectome_${i}_scalenodevol.csv -tck_weights_in tck_weights.txt -symmetric -zero_diagonal -assignment_radial_search 2 -scale_invnodevol
	
	done