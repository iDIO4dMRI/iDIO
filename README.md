# OGIO
---

OGIO is a software toolkit for processing diffusion-weighted MRI data. It integrates the functionalities of modern MRI software packages to constitute a complete data processing pipeline for structural connectivity analysis of the human brain.


## Installation Guide
---

OGIO can be run in Linux and macOS systems. Its major functionalities come from *FSL*, *MRtrix3*, and *ANTS*, and therefore these software tools and their relevant dependencies need to be installed before using OGIO. Please check the links below for the installation of them: 

* *FSL 6.0.3*: <https://fsl.fmrib.ox.ac.uk/fsl/fslwiki>
* *MRtrix3*: <https://www.mrtrix.org/>
* *ANTS*: <https://github.com/ANTsX/ANTs/wiki>

Currently, OGIO also relies on *MATLAB* to perform one specific bias in DWI data (namely DWI signal drifting) and thus requires a few functions of SPM12. To install *MATLAB* and *SPM12*, please see the links below for instructions:

* *MATLAB*: <https://www.mathworks.com/products/matlab.html>
* *SPM12*: <https://www.fil.ion.ucl.ac.uk/spm/software/spm12/>

### Setting
```	
     $ export HOGIO = pipeline location
     $ cp ${HOGIO}/share/MNI/T1_2_ICBM_MNI152_1mm.cnf ${FSL_DIR}/etc/flirtsch
     $ cp ${HOGIO}/share/MNI/mni_icbm152_t1_tal_nlin_asym_09c*.nii.gz ${FSL_DIR}/data/standard
```

## References
---
Please cite the following articles if *OGIO* is utilised in your research publications:

***FSL***
1. Jenkinson, M.; Beckmann, C.F.; Behrens, T.E.; Woolrich, M.W.; Smith. S.M.; FSL. NeuroImage, 2012, 62:782-90
2. Smith, S. M. Fast robust automated brain extraction. Human Brain Mapping, 2002, 17, 143-155
3. Zhang, Y.; Brady, M. & Smith, S. Segmentation of brain MR images through a hidden Markov random field model and the expectation-maximization algorithm. IEEE Transactions on Medical Imaging, 2001, 20, 45-57
4.  Patenaude, B.; Smith, S. M.; Kennedy, D. N. & Jenkinson, M. A Bayesian model of shape and appearance for subcortical brain segmentation. NeuroImage, 2011, 56, 907-922
5.  Smith, S. M.; Jenkinson, M.; Woolrich, M. W.; Beckmann, C. F.; Behrens, T. E.; Johansen-Berg, H.; Bannister, P. R.; De Luca, M.; Drobnjak, I.; Flitney, D. E.; Niazy, R. K.; Saunders, J.; Vickers, J.; Zhang, Y.; De Stefano, N.; Brady, J. M. & Matthews, P. M. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 2004, 23, S208-S219

***MRtrix3***	
1. Tournier, J.-D.; Smith, R. E.; Raffelt, D.; Tabbara, R.; Dhollander, T.; Pietsch, M.; Christiaens, D.; Jeurissen, B.; Yeh, C.-H. & Connelly, A. MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. NeuroImage, 2019, 202, 116137
2. Zhang, Y.; Brady, M. & Smith, S. Segmentation of brain MR images through a hidden Markov random field model and the expectation-maximization algorithm. IEEE Transactions on Medical Imaging, 2001, 20, 45-57
3. Smith, S. M.; Jenkinson, M.; Woolrich, M. W.; Beckmann, C. F.; Behrens, T. E.; Johansen-Berg, H.; Bannister, P. R.; De Luca, M.; Drobnjak, I.; Flitney, D. E.; Niazy, R. K.; Saunders, J.; Vickers, J.; Zhang, Y.; De Stefano, N.; Brady, J. M. & Matthews, P. M. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 2004, 23, S208-S219
4. Dhollander, T.; Mito, R.; Raffelt, D. & Connelly, A. Improved white matter response function estimation for 3-tissue constrained spherical deconvolution. Proc Intl Soc Mag Reson Med, 2019, 555
5. Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. Anatomically-constrained tractography: Improved diffusion MRI streamlines tractography through effective use of anatomical information. NeuroImage, 2012, 62, 1924-1938
6. Jeurissen, B; Tournier, J-D; Dhollander, T; Connelly, A & Sijbers, J. Multi-tissue constrained spherical deconvolution for improved analysis of multi-shell diffusion MRI data. NeuroImage, 2014, 103, 411-426
7. Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography. NeuroImage, 2015, 119, 338-351
8. Tournier, J.-D.; Calamante, F. & Connelly, A. Improved probabilistic streamlines tractography by 2nd order integration over fibre orientation distributions. Proceedings of the International Society for Magnetic Resonance in Medicine, 2010, 1670
9. Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography. NeuroImage, 2015, 119, 338-351
10. Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. The effects of SIFT on the reproducibility and biological accuracy of the structural connectome. NeuroImage, 2015, 104, 253-265
11. Hagmann, P.; Cammoun, L.; Gigandet, X.; Meuli, R.; Honey, C.; Wedeen, V. & Sporns, O. Mapping the Structural Core of Human Cerebral Cortex. PLoS Biology, 2008, 6(7), e159

*** ANTs***
1. Tustison, N. J.; Avants, B. B.; Cook, P. A.; Zheng, Y.; Egan, A.; Yushkevich, P. A. Gee, J. C. N4ITK: Improved N3 Bias Correction. IEEE Transactions on Medical Imaging, 2010, 29(6), 1310-1320

## Complete Tutorial
---
### Data preparing
Images have to include both DWI data and T1 data
#### 1. DICOM images as inputs
Run 0_dcm2bids.sh first

###### 0_dcm2bids.sh
**Synopsis**
automatically convert the DICOM file into ${BIDSDir}/dwi and ${BIDSDir}/anat directory

**Usage**
> sh 0_dcm2bids.sh -d DICOMDir -b OutputBIDSD

- -d DICOMDIR: the input DICOM (.IMA) images (have to include file with dwi and T1w directories)
- -b OutputBIDS: the output images will save as bids format and rename follow the sequence name

**Reference**
- Gorgolewski, K., Auer, T., Calhoun, V. D.,  Craddock, R. C., Das, S., Duff, E. P., Flandin, G., Ghosh, S. S.,  Glatard, T., Halchenko, Y.O., Handwerker, D. A., Hanke, M., Keator, D., Li, X., Michael, Z., Maumet, C., Nichols, B. N., Nichols, T. E., Pellman, J., Poline, J-B., Rokem, A., Schaefer, G., Sochat, V., Triplett, W., Turner, J. A., Varoquaux, G., Poldrack, R. A. The brain imaging data structure, a format for organizing and describing outputs of neuroimaging experiments. Scientific Data, 2016,  3, 160044. 

##### 2. BIDS format images applied
Data have saved in BIDS format 

###### Main.sh
**Synopsis**
implement the OGIO pipeline from Step 1 (1_DWIprep.sh: DWI preprocessing) to Step 6 (6_NetworkProc.sh
: Network generation)

**Usage**
> sh Main.sh -bids InputDir -proc OutputDir [ options ]

- -bids* InputDir*: datapath that including two directory- anat (T1w.nii.gz/T1w.json) and dwi (dwiPHASE.nii.gz, dwi.bval, dwi.bvec, dwi.json)
- -proc *OutputDir* Provide a output path for saving the output processed data

**Options**
- **-cuda** allow eddy to usd an Nvidia GPU if one is available on the system
- **-atlas AtlasDir** by default, those atlas will save in the pipeline dictionary(${HOGIO}/share). Please indicate the atlas path if changed location.


###### 1_DWIprep.sh
**Synopsis**
DWI data preparation (identify phase encoding, generate needed description file)

**Usage**
> sh 1_DWIprep.sh -b InputDir -p OutputDir [ options ]

- -b *InputDir* datapath that including two directory- anat (T1w.nii.gz/T1w.json) and dwi (dwiPHASE.nii.gz, dwi.bval, dwi.bvec, dwi.json)
- -p *OutputDir* Provide a output path for saving the output processed data
```
├── 0_BIDS_NIFTI
│   ├── dwi_AP.bval
│   ├── dwi_AP.bvec
│   ├── dwi_AP.json
│   ├── dwi_AP.nii.gz
│   ├── dwi_PA.bval
│   ├── dwi_PA.bvec
│   ├── dwi_PA.json
│   ├── dwi_PA.nii.gz
│   ├── sub-TPN0100_T1w.json
│   └── sub-TPN0100_T1w.nii.gz
├── 1_DWIprep
│   ├── Acqparams_Topup.txt
│   ├── Eddy_Index.txt
│   ├── Index_PE.txt
│   └── MBF.txt
```

**Options**
- **-c C4**
- **-s PhaseEncode** please provide the number of phase encoding images in following order {PA, AP, LR, RL}

**Reference**
	
###### 2_BiasCo.sh
**Synopsis**
implement the 4D signal denoise, gibbs ringing correction, and drifting correction 

**Usage**
> sh 2_BiasCo.sh  [ options ]

```
├── 2_BiasCo
│   ├── Drifting_Correction_B0only.png
│   ├── Drifting_Correction_allData.png
│   ├── b0_report.txt
│   ├── dwi_APPA-denoise-deGibbs-DriftCo.nii.gz
│   ├── dwi_APPA-denoise-deGibbs.nii.gz
│   ├── dwi_APPA.bval
│   ├── dwi_APPA.bvec
│   ├── dwi_APPA.nii.gz
│   └── temp.nii.gz
```

**Options**
- **-p OutputDir** the OutputDir has to include the 1_DWIprep folder (includes the converted files) [default = pwd directory]

**Reference**
- Vos, S.B., Tax, C.M.W., Luijten, P.R., Ourselin, S., Leemans, A. and Froeling, M. The importance of correcting for signal drift in diffusion MRI. Magnetic Resonance in Medicine, 2017, 77, 285-299


###### 3_EddyCo.sh
**Synopsis**
implement the distortion and eddy correction

**Usage**
> sh 3_eddyCo.sh [ options ]
```
├── 3_EddyCo
│   ├── Acqparams_Topup.txt
│   ├── B0.nii.gz
│   ├── B0.topup_log
│   ├── Eddy_Index.txt
│   ├── Field.nii.gz
│   ├── Mean_Unwarped_Images.nii.gz
│   ├── Mean_Unwarped_Images_Brain.nii.gz
│   ├── Mean_Unwarped_Images_Brain_mask.nii.gz
│   ├── Topup_Output_fieldcoef.nii.gz
│   ├── Topup_Output_movpar.txt
│   ├── Unwarped_Images.nii.gz
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.bval
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.bvec
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_command_txt
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_movement_rms
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_outlier_map
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_outlier_n_sqr_stdev_map
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_outlier_n_stdev_map
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_outlier_report
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_parameters
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_post_eddy_shell_PE_translation_parameters
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_post_eddy_shell_alignment_parameters
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_restricted_movement_rms
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_values_of_all_input_parameters
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.nii.gz
│   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.qc
│   │   ├── avg_b0.png
│   │   ├── avg_b1000.png
│   │   ├── avg_b3000.png
│   │   ├── qc.json
│   │   ├── qc.pdf
│   │   ├── ref.txt
│   │   └── ref_list.png
│   ├── dwi_APPA-denoise-deGibbs-DriftCo.nii.gz
│   ├── first_B0.nii.gz
│   └── second_B0.nii.gz
```

**Options**
- **-p OutputDir** the OutputDir has to include the 1_DWIprep and 2_BiasCo folder (includes the converted files). [default = pwd directory]
- **-c** using CUDA to accelerate the correction process. Both CUDA v9.1 and v8.0 is available. [default = none]
* **-m** with -c, -m is applicable for slice-to-volume motion correction.

**Reference**
- Graham M. S., Drobnjak I., Jenkinson M., Zhang H. Quantitative assessment of the susceptibility artefact and its interaction with motion in diffusion MRI. PLOS ONE, 2017, 12(10), e0185647.


###### 4_DTIFIT.sh
**Synopsis**
Diffusion tensor estimation. Only low-b (b<1500 s/mm^2) images were used for further fitting.

**Usage**
> sh 4_DTIFIT.sh [ options ]
```
├── 4_DTIFIT
│   ├── sub-TPN0100-preproc-Average_b0-brain.nii.gz
│   ├── sub-TPN0100-preproc-Average_b0-brain_mask.nii.gz
│   ├── sub-TPN0100-preproc-Average_b0.nii.gz
│   ├── sub-TPN0100-preproc-lowb-data.bval
│   ├── sub-TPN0100-preproc-lowb-data.bvec
│   ├── sub-TPN0100-preproc-lowb-data.nii.gz
│   ├── sub-TPN0100-preproc-unbiased.nii.gz
│   ├── sub-TPN0100-preproc.bval
│   ├── sub-TPN0100-preproc.bvec
│   ├── sub-TPN0100-preproc.nii.gz
│   ├── sub-TPN0100_FA.nii.gz
│   ├── sub-TPN0100_L1.nii.gz
│   ├── sub-TPN0100_L2.nii.gz
│   ├── sub-TPN0100_L3.nii.gz
│   ├── sub-TPN0100_MD.nii.gz
│   ├── sub-TPN0100_MO.nii.gz
│   ├── sub-TPN0100_RD.nii.gz
│   ├── sub-TPN0100_S0.nii.gz
│   ├── sub-TPN0100_V1.nii.gz
│   ├── sub-TPN0100_V2.nii.gz
│   └── sub-TPN0100_V3.nii.gz
```

**Options**
- **-p OutputDir** the ProcPath has to include the 2_BiasCo and 3_EddyCo folder (includes the converted files). [default = pwd directory]
- **-t BzeroThreshold** input the Bzero threshold. [default = 10]

**Reference**
- Tustison, N.; Avants, B.; Cook, P.; Zheng, Y.; Egan, A.; Yushkevich, P. & Gee, J. N4ITK: Improved N3 Bias Correction. IEEE Transactions on Medical Imaging, 2010, 29, 1310-1320
- Basser, P.J.; Mattiello, J; LeBihan, D; Estimation of the effective self-diffusion tensor from the NMR spin echo. Journal of Magnetic Resonance, Series B, 1994, 103(3), 247-254

###### 5_CSDpreproc.sh 
**Synopsis**
DWI preprocessing of constrained spherical deconvolution with Dhollanders algorithms

**Usage**
> sh 5_CSDpreproc.sh [ options ]
```
├── 5_CSDpreproc
│   ├── S1_T1proc
│   │   ├── 5tt2dwispace.nii.gz
│   │   ├── Reg_matrix
│   │   │   ├── T12DWI_flirt6.mat
│   │   │   ├── T12DWI_mrtrix.txt
│   │   │   ├── mni2str_nonlinear_transf.nii.gz
│   │   │   ├── str2mni_affine_transf.mat
│   │   │   └── str2mni_nonlinear_transf.nii.gz
│   │   ├── T12dwispace.nii.gz
│   │   ├── T1_BET
│   │   │   ├── sub-TPN0100_T1w.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_bias.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_mixeltype.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_prob_0.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_prob_1.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_prob_2.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_pve_0.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_pve_1.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_pve_2.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_pveseg.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_restore.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_seg.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_seg_0.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_seg_1.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_Corrected_seg_2.nii.gz
│   │   │   ├── sub-TPN0100_T1w_bet_mask.nii.gz
│   │   │   └── sub-TPN0100_T1w_to_mni_icbm152_t1_tal_nlin_asym_09c.log
│   │   └── WMGM2dwispace.nii.gz
│   ├── S2_Response
│   │   ├── odf_csf.mif
│   │   ├── odf_csf_norm.mif
│   │   ├── odf_gm.mif
│   │   ├── odf_gm_norm.mif
│   │   ├── odf_wm.mif
│   │   ├── odf_wm_norm.mif
│   │   ├── response_csf.txt
│   │   ├── response_gm.txt
│   │   └── response_wm.txt
│   ├── S3_Tractography
│   │   ├── SIFT2_weights.txt
│   │   ├── SIFT_mu.txt
│   │   └── track_DynamicSeed_1M.tck
│   ├── sub-TPN0100-preproc-mask-erode.mif
│   ├── sub-TPN0100-preproc-unbiased.mif
│   ├── sub-TPN0100-preproc.bval
│   └── sub-TPN0100-preproc.bvec
```

**Options**
- **-p OutputDir** the OutputDir has to include the 3_EddyCo and 4_DTIFIT folder (includes the converted files). [default = pwd directory]
- **-t BzeroThreshold** input the Bzero threshold. [default = 10]

**Reference**
- Smith, S. M. Fast robust automated brain extraction. Human Brain Mapping, 2002, 17, 143-155
- Zhang, Y.; Brady, M. & Smith, S. Segmentation of brain MR images through a hidden Markov random field model and the expectation-maximization algorithm. IEEE Transactions on Medical Imaging, 2001, 20, 45-57
- Patenaude, B.; Smith, S. M.; Kennedy, D. N. & Jenkinson, M. A Bayesian model of shape and appearance for subcortical brain segmentation. NeuroImage, 2011, 56, 907-922
- Smith, S. M.; Jenkinson, M.; Woolrich, M. W.; Beckmann, C. F.; Behrens, T. E.; Johansen-Berg, H.; Bannister, P. R.; De Luca, M.; Drobnjak, I.; Flitney, D. E.; Niazy, R. K.; Saunders, J.; Vickers, J.; Zhang, Y.; De Stefano, N.; Brady, J. M. & Matthews, P. M. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 2004, 23, S208-S219
- Dhollander, T.; Mito, R.; Raffelt, D. & Connelly, A. Improved white matter response function estimation for 3-tissue constrained spherical deconvolution. Proc Intl Soc Mag Reson Med, 2019, 555
- Raffelt, D.; Dhollander, T.; Tournier, J.-D.; Tabbara, R.; Smith, R. E.; Pierre, E. & Connelly, A. Bias Field Correction and Intensity Normalisation for Quantitative Analysis of Apparent Fibre Density. In Proc. ISMRM, 2017, 26, 3541

###### 6_NetworkProc.sh
**Synopsis**
Generate the tractogram based (anatomical constrained tractography with dynamic seeding and SIFT). Connectivity matrix will be generated with five atlases (AAL3, DK, HCPMMP w/o Subcortical regions, Yeo)

**Usage**
> sh 6_NetworkProc.sh [ options ]
```
├── 6_NetworkProc
│   ├── Atlas
│   │   ├── sub-TPN0100_AAL3_resample_ICBM_inDWI.nii.gz
│   │   ├── sub-TPN0100_AAL3_resample_ICBM_inT1.nii.gz
│   │   ├── sub-TPN0100_DK_resample_ICBM_inDWI.nii.gz
│   │   ├── sub-TPN0100_DK_resample_ICBM_inT1.nii.gz
│   │   ├── sub-TPN0100_HCPMMP_SUBC_resample_ICBM_inDWI.nii.gz
│   │   ├── sub-TPN0100_HCPMMP_SUBC_resample_ICBM_inT1.nii.gz
│   │   ├── sub-TPN0100_HCPMMP_resample_ICBM_inDWI.nii.gz
│   │   ├── sub-TPN0100_HCPMMP_resample_ICBM_inT1.nii.gz
│   │   ├── sub-TPN0100_Yeo400_resample_ICBM_inDWI.nii.gz
│   │   └── sub-TPN0100_Yeo400_resample_ICBM_inT1.nii.gz
│   ├── sub-TPN0100_AAL3_resample_ICBM_Assignments.csv
│   ├── sub-TPN0100_DK_resample_ICBM_Assignments.csv
│   ├── sub-TPN0100_HCPMMP_SUBC_resample_ICBM_Assignments.csv
│   ├── sub-TPN0100_HCPMMP_resample_ICBM_Assignments.csv
│   ├── sub-TPN0100_Yeo400_resample_ICBM_Assignments.csv
│   ├── sub-TPN0100_connectome_AAL3_resample_ICBM.csv
│   ├── sub-TPN0100_connectome_AAL3_resample_ICBM_scalenodevol.csv
│   ├── sub-TPN0100_connectome_DK_resample_ICBM.csv
│   ├── sub-TPN0100_connectome_DK_resample_ICBM_scalenodevol.csv
│   ├── sub-TPN0100_connectome_HCPMMP_SUBC_resample_ICBM.csv
│   ├── sub-TPN0100_connectome_HCPMMP_SUBC_resample_ICBM_scalenodevol.csv
│   ├── sub-TPN0100_connectome_HCPMMP_resample_ICBM.csv
│   ├── sub-TPN0100_connectome_HCPMMP_resample_ICBM_scalenodevol.csv
│   ├── sub-TPN0100_connectome_Yeo400_resample_ICBM.csv
│   └── sub-TPN0100_connectome_Yeo400_resample_ICBM_scalenodevol.csv
```

**Options**
- **-p OutputDir** the OutputDir has to include the 5_CSDpreproc folder (includes the converted files). [default = pwd directory]
- **-a AtlasDir** the Atlas directory [default = ${HOGIO}/share/Atlas]

**Reference**
- Smith, S. M. Fast robust automated brain extraction. Human Brain Mapping, 2002, 17, 143-155
- Jenkinson, M.; Bannister, P.; Brady, J. M. & Smith, S. M. Improved Optimisation for the Robust and Accurate Linear Registration and Motion Correction of Brain Images. NeuroImage, 2002, 17(2), 825-841
- Tournier, J.-D.; Calamante, F. & Connelly, A. Improved probabilistic streamlines tractography by 2nd order integration over fibre orientation distributions. Proceedings of the International Society for Magnetic Resonance in Medicine, 2010, 1670
- Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. Anatomically-constrained tractography: Improved diffusion MRI streamlines tractography through effective use of anatomical information. NeuroImage, 2012, 62, 1924-1938
- Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography. NeuroImage, 2015, 119, 338-351
- Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. The effects of SIFT on the reproducibility and biological accuracy of the structural connectome. NeuroImage, 2015, 104, 253-265
- Hagmann, P.; Cammoun, L.; Gigandet, X.; Meuli, R.; Honey, C.; Wedeen, V. & Sporns, O. Mapping the Structural Core of Human Cerebral Cortex. PLoS Biology 6(7), e159