# iDIO
---

iDIO is a software toolkit for processing diffusion-weighted MRI data. It integrates the functionalities of modern MRI software packages to constitute a complete data processing pipeline for structural connectivity analysis of the human brain.


## Installation Guide
---

iDIO can be run in Linux and macOS environment (Most recommend: Linux) . Its major functionalities come from ***Mrtrix3***,  ***FSL***,  ***ANTS***, and ***PreQual*** . Details for each software tools can be found in the links below: 

* [*FSL v6.0.3*](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)
* [*MRtrix3*](https://www.mrtrix.org/)
* [*ANTS v2*](http://stnava.github.io/ANTs/)
* [*PreQual v7*](https://github.com/MASILab/PreQual)

Currently, iDIO relies on command-line shell functions from ***MRtrix3***, ***FSL***, and ***ANTs***, and therefore these software tools and their relevant dependencies need to be installed before using iDIO.  iDIO also relies on ***Python3*** to perform (1) bias correction in DWI data (namely DWI signal drifting), (2) scaling the connectivity matrix with mu and (3).  Requires a few Python3 library: including argparse(1.4.0), numpy(1.18.1), pandas(0.24.2), scipy(1.2.1), nibabel(3.2.0), scikit-image(0.18.1) and matplotlib(3.0.3), you may install those library with pip

you can install those library with:
```
$ pip install argparse numpy pandas nibabel scikit-image matplotlib
```

### Setting
before started, it is necessary to export the home directory of iDIO as iDIO_HOME. 
```	
$ export iDIO_HOME = iDIO pipeline location
```


---
## Tutorial

### Data preparing
The iDIO pipeline require DWI data and T1 data to be stored in Brain Imaging Data Structure (BIDS) format, where the modality is indicated in the suffix of each image file. JSON file for each sequence is necessary for iDIO preprocess. iDIO also support DWIs with only one phase encoding. 

an example is as follows: 

```          
sub-001
├── anat
│    ├── sub-001_T1w.json
│    └── sub-001_T1w.nii.gz
└── dwi
	 ├── sub-001_acq-multibandAP_dwi.bval
	 ├── sub-001_acq-multibandAP_dwi.bvec
	 ├── sub-001_acq-multibandAP_dwi.json
	 ├── sub-001_acq-multibandAP_dwi.nii.gz
	 ├── sub-001_acq-multibandPA_dwi.bval
	 ├── sub-001_acq-multibandPA_dwi.bvec
	 ├── sub-001_acq-multibandPA_dwi.json
	 └── sub-001_acq-multibandPA_dwi.nii.gz
```

### One-click solution: run Main.sh with argument file (SetUpOGIOArg.sh)
**Synopsis**
Performing the iDIO pipeline with predefined options.  

**Usage**
> bash Main.sh -bids *InputDir* -proc *OutputDir* -arg *SetUpiDIOArg.sh*

- **-bids InputDir**: Data path that including two directories - anat (T1w.nii.gz/T1w.json) and dwi (dwiPHASE.nii.gz, dwiPHASE.bval, dwiPHASE.bvec, dwiPHASE.json) (As shown in the ** Data preparing** section above. Note: **T1w** and **dwi** are case sensitive)
- **-proc OutputDir**: Provide a output path for saving the output processed data
- **-arg SetUpiDIOArg.sh**: Provide a script that include all needed predefined options. \[default = ${IDIO_HOME}/SetUpiDIOArg.sh if not provided\] (For more details, please see **Options** below)

**Options**
All options need to be predefined are list in the ** SetUpiDIOArg.sh** file. A template file is stored in the home directory of iDIO.  iDIO pipeline include eight steps in the following order, (1) data preprocessing, (2) bias correction, (3) eddy correction, (4) T1 preprocessing,  (5) diffusion tensor fitting, (6) constrained spherical deconvolution processing, (7)network construction and (8)quality control

- **Step**: Set the wanted processing steps to perform [default=1.2.3.4.5.6.7.8]
- **first/second**: If the series number is not recorded in the JSON file, please provide the filename by the scan order [default=None]
- **cuda** : A boolean value to indicate whether to run the CUDA version of eddy to speed up the processing procedure. iDIO will automatically selected the supported cuda version (8.0/9.1/10.2) if the processing server has discrete GPU installed with CUDA. [default=0]
- **stv**: A boolean value to indicate whether to perform the slice-to-volume correction. Slice-to-volume correction only implemented for CUDA version. [default=0]
- **rsimg**: Specifies the isotropic voxel size (mm) of DWIs, which will be apply  before step (5) diffusion tensor fitting and step (6) constrained spherical deconvolution. [default=0 (no resize)]
- **bzero**: Specifies the values to determine the null image with certain b-value threshold [default = 10]
- **AtlasDir**: Default needed files were save in ${iDIO_HOME}/share with several folders, we recommend not to change this path, but save Atlas you need  in ${iDIO_HOME}/share/Atlas instead. [default = ${iDIO_HOME}/share]
- **trkNum**: Specifies the desired number of streamlines to be selected when generating the tractogram [default = 10M]
      
### Recommended imaging acquisition
There are some recommendation for imaging acquisition for further iDIO preprocessing. 

- Assured that image acquisition **did not undergo an image interpolation** to prevent change in noise distribution. (turn off the interpolation option on the vendor machine to prevent this issue). 
- Gibbs ring removal relies on **full k-space** coverage data, data that did not meet the requirement have to be aware of a suboptimal result. 
- Evenly distributed **interleaved b=0 images** may provide a better estimation of the image signal drifting profile. 
- Acquiring diffusion data using an **entire sphere diffusion encoding** manner with **phase encode reversed image (at least with b=0 images)**, which may be able to run all corrections of susceptibility-induced distortion, eddy current-induced distortion and subject movement. 
- Tips in image acquisition with Siemens simultaneous multi-slice images: number of slices divided by the multiband factor has to be and odd number to prevent the artifactually bright slices in the image ([Andersson et al., 2017]( https://www.sciencedirect.com/science/article/pii/S1053811917301945); [Center for Magnetic Resonance Research, 2012](https://wiki.humanconnectome.org/download/attachments/40534057/CMRR_MB_Slice_Order.pdf).
- If diffusion tensor fitting is required, at least 13 diffusion directions are needed with a b-value lower than 1500 s/mm<sup>2</sup>. For CSD, multi-shell diffusion weighted imaging is recommended. At least one low b-value shell and one high b-value shell (greater than 2000 s/mm<sup>2</sup>) with more than 45 diffusion directions is recommended to provide better angular resolution of CSD modelling and have advantages in modelling multi-tissue response function ([Tournier et al., 2013](https://analyticalsciencejournals.onlinelibrary.wiley.com/doi/10.1002/nbm.3017)) 


### Details of each step
#### Step 0: CheckData.sh

**Synopsis**

This is not embeded in the main script. This script aims to Initially check the data accessibility with proper reverse phase diffusion images in matched folder.

**Usage**

> bash 0_CheckData.sh -b *BIDSDir*

- **-b InputDir** datapath that including two directory- anat (T1w.nii.gz/T1w.json) and dwi (dwiPHASE.nii.gz, dwi.bval, dwi.bvec, dwi.json)

#### Step 1: 1_DWIprep.sh
**Synopsis**
DWI data preparation (identify phase encoding of DWI image and generate needed description files in 0_BIDS_NIFTI and 1_DWIprep folders)

```      
└── OutputDir
	 ├── 0_BIDS_NIFTI
	 │   ├── T1w.json
	 │   ├── T1w.nii.gz
	 │   ├── dwi_AP.bval
	 │   ├── dwi_AP.bvec
	 │   ├── dwi_AP.json
	 │   ├── dwi_AP.nii.gz
	 │   ├── dwi_PA.bval
	 │   ├── dwi_PA.bvec
	 │   ├── dwi_PA.json
	 │   └── dwi_PA.nii.gz
	 ├── 1_DWIprep
	 │   ├── Acqparams_Topup.txt
	 │   ├── Eddy_Index.txt
	 │   ├── Index_PE.txt
	 │   └── MBF.txt
```
**Usage**
> bash 1_DWIprep.sh -b *InputDir* -p *OutputDir* [ options ]

- **-b InputDir** datapath that including two directory- anat (T1w.nii.gz/T1w.json) and dwi (dwiPHASE.nii.gz, dwiPHASE.bval, dwiPHASE.bvec, dwiPHASE.json) *Note: T1w and dwi are case sensitive.*
- **-p OutputDir** Provide a output path for saving the output processed data 

**Options**

- **-first 1stFilename** filename of the former acquired diffusion data, no need to specifty the filename extension (i.e. dwi1) 
- **-second 2ndFilename** filename of the latter acquired diffusion data, no need to specifty the filename extension (i.e. dwi2)

**Reference**
	
#### 2_BiasCo.sh
**Synopsis**
implement the 4D signal denoise, gibbs ringing correction, and drifting correction 

**Usage**
> bash 2_BiasCo.sh  [ options ]

```      
└── OutputDir
         ├── 2_BiasCo
	 │   ├── Drifting_Correction_B0only.png
	 │   ├── Drifting_Correction_allData.png
	 │   ├── Drifting_val.csv
	 │   ├── Res.nii.gz
     	 │   ├── dwi_AP-denoise.nii.gz
	 │   ├── dwi_AP-noise.nii.gz
	 │   ├── dwi_APPA-denoise-deGibbs-DriftCo.nii.gz
	 │   ├── dwi_APPA-denoise-deGibbs.nii.gz
	 │   ├── dwi_APPA.bval
         │   ├── dwi_APPA.bvec
	 │   └── dwi_APPA.nii.gz
```

**Options**
- **-p OutputDir** the OutputDir has to include the 1_DWIprep folder (includes the converted files) [default = pwd directory]

#### 3_EddyCo.sh
**Synopsis**
implement the distortion and eddy correction. Preprocessed_data folder will be generated when 3_Eddyco is finished
```
└── OutputDir
	 ├── 3_EddyCo
	 │   ├── Acqparams_Topup.txt
	 │   ├── B0.nii.gz
	 │   ├── B0.topup_log
	 │   ├── DWI.json
	 │   ├── Eddy_Index.txt
	 │   ├── Field.nii.gz
	 │   ├── Mean_Unwarped_Images.nii.gz
	 │   ├── Mean_Unwarped_Images_Brain.nii.gz
	 │   ├── Mean_Unwarped_Images_Brain_mask.nii.gz
	 │   ├── Topup_Output_fieldcoef.nii.gz
	 │   ├── Topup_Output_movpar.txt
	 │   ├── Unwarped_Images.nii.gz	      
	 │   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo-BiasField.nii.gz
	 │   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo-unbiased.nii.gz
	 │   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.bval
	 │   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.bvec	      
	 │   ├── dwi_APPA-denoise-deGibbs-DriftCo-EddyCo.eddy_cnr_maps.nii.gz
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
**Usage**
> bash 3_eddyCo.sh [ options ]

**Options**      

- **-p OutputDir** The OutputDir has to include the 1_DWIprep and 2_BiasCo folder (includes the converted files). [default = pwd directory]
- **-c Boolean** Usng CUDA to accelerate the correction process. Both CUDA v8.0, v9.1 and v10.2 are available. [default = 0]
- **-m Boolean** with -c, -m is applicable for slice-to-volume motion correction. [default = 0]
- **-r size(mm)** Resize dwi image to isotropic voxel with input value size [default =0 (do not resize)].
- **-t B0thr**  Bzero threshold; [default = 10];

#### 4_T1preproc.sh
**Synopsis**
T1 preprocessing: Creating brain mask, registration of T1w and Diff images. Negative values on preprocessed image wil be reported
（ Negative values in preprocessed T1 image, which could be generated during the Gibbs ring removal step, will be replaced with zeros to prevent errors in other T1 processing. ）

```
└── OutputDir     
    ├── 4_T1preproc
    │   ├── 5tt.nii.gz
    │   ├── 5tt2dwispace.nii.gz
    │   ├── Average_b0-brain.nii.gz
    │   ├── Reg_matrix
    │   │   ├── epi2str.mat
    │   │   ├── epi2str_init.mat
    │   │   ├── str2epi.mat
    │   │   └── str2epi.txt
    │   ├── T1maskindwispace.nii.gz
    │   ├── T1w-deGibbs-BiasCo-Brain.nii.gz
    │   ├── T1w-deGibbs-BiasCo-Brain_pve_0.nii.gz
    │   ├── T1w-deGibbs-BiasCo-Brain_pve_1.nii.gz
    │   ├── T1w-deGibbs-BiasCo-Brain_pve_2.nii.gz
    │   ├── T1w-deGibbs-BiasCo-Brain_pveseg.nii.gz
    │   ├── T1w-deGibbs-BiasCo-Mask.nii.gz
    │   ├── T1w-deGibbs-BiasCo-Prior0GenericAffine.mat
    │   ├── T1w-deGibbs-BiasCo.nii.gz
    │   ├── T1w-deGibbs.nii.gz
    │   ├── T1w.nii.gz
    │   ├── T1w_BiasField.nii.gz
    │   ├── T1w_preprocessed.nii.gz
    │   └── WMseg.nii.gz
```
**Usage**
> bash 4_T1preproc.sh [ options ]

**Options**
- **-p OutputDir** The ProcPath has to include the 2_BiasCo and 3_EddyCo folder (includes the converted files). [default = pwd directory]
- **-a AtlasDir**  The Atlas directory with MNI normalized images [default = ${iDIO_HOME}/share/]

#### 5_DTIFIT.sh
**Synopsis**
Diffusion tensor estimation. Only low-b (b<1500 s/mm^2) images were used for further fitting.
```
└── OutputDir     
         ├── 5_DTIFIT
         │   ├── Average_b0.nii.gz
         │   ├── Process-preproc-lowb-data.bval
         │   ├── Process-preproc-lowb-data.bvec
         │   ├── Process-preproc-lowb-data.nii.gz
         │   ├── Process-preproc.bval
         │   ├── Process-preproc.bvec
         │   ├── Process-preproc.nii.gz      
	 │   ├── POST_OPT_DEC.nii.gz
         │   ├── Process_FA.nii.gz
         │   ├── Process_L1.nii.gz
         │   ├── Process_L2.nii.gz
         │   ├── Process_L3.nii.gz
         │   ├── Process_MD.nii.gz
         │   ├── Process_MO.nii.gz
         │   ├── Process_RD.nii.gz
         │   ├── Process_S0.nii.gz
         │   ├── Process_V1.nii.gz
         │   ├── Process_V2.nii.gz
         │   ├── Process_V3.nii.gz      
	 │   ├── POST_OPT_sse.nii.gz	
         │   └── T1w_mask_inDWIspace.nii.gz
```
**Usage**
> bash 5_DTIFIT.sh [ options ]

**Options**
- **-p OutputDir** The ProcPath has to include the 2_BiasCo and 3_EddyCo folder (includes the converted files). [default = pwd directory]
- **-t B0thr**  Bzero threshold; [default = 10];

#### 6_CSDpreproc.sh
**Synopsis**
DWI preprocessing of constrained spherical deconvolution with Dhollanders algorithms
```
└── OutputDir      
    ├── 6_CSDpreproc
    │   ├── S1_Response
    │   │   ├── odf_csf.mif
    │   │   ├── odf_csf_norm.mif
    │   │   ├── odf_gm.mif
    │   │   ├── odf_gm_norm.mif
    │   │   ├── odf_wm.mif
    │   │   ├── odf_wm_norm.mif
    │   │   ├── response_csf.txt
    │   │   ├── response_gm.txt
    │   │   └── response_wm.txt
    │   ├── T1w_mask_inDWIspace.nii.gz
    │   ├── dwi_preprocessed.bval
    │   ├── dwi_preprocessed.bvec
    │   ├── dwi_preprocessed.mif
    │   └── dwi_preprocessed.nii.gz
```
**Usage**
> bash 6_CSDpreproc.sh [ options ]

**Options**
- **-p OutputDir** The OutputDir has to include the 3_EddyCo and 4_DTIFIT folder (includes the converted files). [default = pwd directory]
- **-t B0thr** Bzero threshold. [default = 10];

#### 7_NetworkProc.sh
**Synopsis**
Generate the tractogram based (anatomical constrained tractography with dynamic seeding and SIFT). Connectivity matrix with different scaled (SIFT2 weights, SIFT2 with mu and length) will be generated with four atlases (AAL3, HCPMMP w/o Subcortical regions(HCPex), and Yeo400) and save in Connectivity_Matrix folder. A

, cropping the streamline endpoints at GM-WM interface and enabling the ‘backtracking’ mechanism. Minimal and maximal streamline length was set as 5 and 250, respectively, and other options remain default (see tckgen command for the details).
```
└── OutputDir  
    ├── 7_NetworkProc
    │   ├── Reg_matrix
    │   │   ├── T12MNI_0GenericAffine.mat
    │   │   ├── T12MNI_1InverseWarp.nii.gz
    │   │   ├── T12MNI_1Warp.nii.gz
    │   │   ├── T12MNI_InverseWarped.nii.gz
    │   │   └── T12MNI_Warped.nii.gz
    │   ├── SIFT2_weights.txt
    │   ├── SIFT_mu.txt
    │   └── Track_DynamicSeed_10M.tck
    ├── Connectivity_Matrix
    │   ├── Assignment
    │   │   ├── AAL3_Assignments.csv
    │   │   ├── HCPMMP_Assignments.csv
    │   │   ├── HCPex_Assignments.csv
    │   │   └── Yeo400_Assignments.csv
    │   ├── Atlas
    │   │   ├── AAL3_inDWI.nii.gz
    │   │   ├── AAL3_inT1.nii.gz
    │   │   ├── HCPMMP_inDWI.nii.gz
    │   │   ├── HCPMMP_inT1.nii.gz
    │   │   ├── HCPex_inDWI.nii.gz
    │   │   ├── HCPex_inT1.nii.gz
    │   │   ├── Yeo400_inDWI.nii.gz
    │   │   └── Yeo400_inT1.nii.gz
    │   ├── Mat_Length
    │   │   ├── AAL3_Length.csv
    │   │   ├── HCPMMP_Length.csv
    │   │   ├── HCPex_Length.csv
    │   │   └── Yeo400_Length.csv
    │   ├── Mat_SIFT2Wei
    │   │   ├── AAL3_SIFT2.csv
    │   │   ├── HCPMMP_SIFT2.csv
    │   │   ├── HCPex_SIFT2.csv
    │   │   └── Yeo400_SIFT2.csv
    │   └── Mat_ScaleMu
    │       ├── AAL3_ScaleMu.csv
    │       ├── HCPMMP_ScaleMu.csv
    │       ├── HCPex_ScaleMu.csv
    │       └── Yeo400_ScaleMu.csv
```
**Usage**
> bash 7_NetworkProc.sh [ options ]

**Options**
- **-p OutputDir** The OutputDir has to include the 5_CSDpreproc folder (includes the converted files). [default = pwd directory]
- **-a AtlasDir** The Atlas directory [default = ${iDIO_HOME}/share/]
- **-n TrackNum** Select track number; [default = 10M] (Please be aware of storage apace)
#### run_IDIOQC.py
**synopsis**
Implement the quality control process and generate a report for iDIO diffusion preprocessing pipeline with pre-/post- processing comparison and related statistic values in a csv file. 
```
└── OutputDir       
	├── 8_QC
	│   ├── N0001_POST_OPT_QC.pdf
	│   └── stats.csv

```
**Usage**
> python run_IDIOQC.py -p OutputDIr -a AtlasDir -t B0thr

**Options**
- **-p OutputDIr** Path of the iDIO PreprocDir (at least with directories from step 1 to 4)
- **-a AtlasDir** Path of the Template directory (include /MNI/QC/JHU-ICBM-FA-1mm.nii.gz and /MNI/QC/JHU-ICBM-labels-1mm.nii.gz)
- **-t B0thr** Bzero threshold. [default = 10]


####  Preprocessed_data and mainlog.txt
For other purpose that may need preprocessed dwi and T1 image data, we save the preporcessed data in the Preprocessed_data folder. a log file with all options and information with processing time were save in the mainlog.txt in the main output dir.
```
└── OutputDir         
    ├── Preprocessed_data
    │   ├── DWI.json
    │   ├── T1w_mask.nii.gz
    │   ├── T1w_mask_inDWIspace.nii.gz
    │   ├── T1w_preprocessed.nii.gz
    │   ├── dwi_preprocessed-Average_b0-brain.nii.gz
    │   ├── dwi_preprocessed-Average_b0.nii.gz
    │   ├── dwi_preprocessed.bval
    │   ├── dwi_preprocessed.bvec
    │   └── dwi_preprocessed.nii.gz
    └── mainlog.txt
```

## References
Please cite the following articles if *iDIO* is utilized in your research publications:

### ***FSL***
1. [Graham M. S., Drobnjak I., Jenkinson M., Zhang H. Quantitative assessment of the susceptibility artefact and its interaction with motion in diffusion MRI. PLOS ONE, 2017, 12(10), e0185647](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0185647)
1. [Jenkinson, M.; Beckmann, C.F.; Behrens, T.E.; Woolrich, M.W.; Smith. S.M.; FSL. NeuroImage, 2012, 62:782-90](https://linkinghub.elsevier.com/retrieve/pii/S1053-8119(11)01060-3)
2. [Jenkinson, M.; Bannister, P.; Brady, J. M. & Smith, S. M. Improved Optimisation for the Robust and Accurate Linear Registration and Motion Correction of Brain Images. NeuroImage, 2002, 17(2), 825-841](https://www.sciencedirect.com/science/article/pii/S1053811902911328?via%3Dihub)
3. [Patenaude, B.; Smith, S. M.; Kennedy, D. N. & Jenkinson, M. A Bayesian model of shape and appearance for subcortical brain segmentation. NeuroImage, 2011, 56, 907-922](https://www.sciencedirect.com/science/article/pii/S1053811911002023?via%3Dihub)
3. [Smith, S. M. Fast robust automated brain extraction. Human Brain Mapping, 2002, 17, 143-155](https://onlinelibrary.wiley.com/doi/10.1002/hbm.10062)
4. [Smith, S. M.; Jenkinson, M.; Woolrich, M. W.; Beckmann, C. F.; Behrens, T. E.; Johansen-Berg, H.; Bannister, P. R.; De Luca, M.; Drobnjak, I.; Flitney, D. E.; Niazy, R. K.; Saunders, J.; Vickers, J.; Zhang, Y.; De Stefano, N.; Brady, J. M. & Matthews, P. M. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 2004, 23, S208-S219](https://www.sciencedirect.com/science/article/pii/S1053811904003933?via%3Dihub)
7.  [Zhang, Y.; Brady, M. & Smith, S. Segmentation of brain MR images through a hidden Markov random field model and the expectation-maximization algorithm. IEEE Transactions on Medical Imaging, 2001, 20, 45-57](https://ieeexplore.ieee.org/document/906424)

### ***MRtrix3***
1. [Dhollander, T.; Mito, R.; Raffelt, D. & Connelly, A. Improved white matter response function estimation for 3-tissue constrained spherical deconvolution. Proc Intl Soc Mag Reson Med, 2019, 555](https://archive.ismrm.org/2019/0555.html)
1. [Hagmann, P.; Cammoun, L.; Gigandet, X.; Meuli, R.; Honey, C.; Wedeen, V. & Sporns, O. Mapping the Structural Core of Human Cerebral Cortex. PLoS Biology, 2008, 6(7), e159](https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.0060159)
3. [Jeurissen, B; Tournier, J-D; Dhollander, T; Connelly, A & Sijbers, J. Multi-tissue constrained spherical deconvolution for improved analysis of multi-shell diffusion MRI data. NeuroImage, 2014, 103, 411-426](https://www.sciencedirect.com/science/article/pii/S1053811914006442?via%3Dihub)
4. [Raffelt, D.; Dhollander, T.; Tournier, J.-D.; Tabbara, R.; Smith, R. E.; Pierre, E. & Connelly, A. Bias Field Correction and Intensity Normalisation for Quantitative Analysis of Apparent Fibre Density. In Proc. ISMRM, 2017, 26, 3541](https://archive.ismrm.org/2017/3541.html)
5. [Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. Anatomically-constrained tractography: Improved diffusion MRI streamlines tractography through effective use of anatomical information. NeuroImage, 2012, 62, 1924-1938](https://www.sciencedirect.com/science/article/pii/S1053811912005824?via%3Dihub)
6. [Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. The effects of SIFT on the reproducibility and biological accuracy of the structural connectome. NeuroImage, 2015, 104, 253-265](https://www.sciencedirect.com/science/article/pii/S1053811915005972?via%3Dihub)
1. [Tournier, J.-D.; Smith, R. E.; Raffelt, D.; Tabbara, R.; Dhollander, T.; Pietsch, M.; Christiaens, D.; Jeurissen, B.; Yeh, C.-H. & Connelly, A. MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. NeuroImage, 2019, 202, 116137](https://www.sciencedirect.com/science/article/pii/S1053811919307281?via%3Dihub)
7. [Tournier, J.-D.; Calamante, F. & Connelly, A. Improved probabilistic streamlines tractography by 2nd order integration over fibre orientation distributions. Proceedings of the International Society for Magnetic Resonance in Medicine, 2010, 1670](https://archive.ismrm.org/2010/1670.html)

### ***ANTs***
1. [Tustison, N. J.; Avants, B. B.; Cook, P. A.; Zheng, Y.; Egan, A.; Yushkevich, P. A. Gee, J. C. N4ITK: Improved N3 Bias Correction. IEEE Transactions on Medical Imaging, 2010, 29(6), 1310-1320](https://ieeexplore.ieee.org/document/5445030)
2. [Tustison, N.J.; Cook, P.A.; Klein A.; Song, G.; Das, S.R.; Duda, J.T.; Kandel, B.M.; van Strien, N.; Stone, J.R.; Gee, J.C.; Avants, B.B. Large-scale evaluation of ANTs and FreeSurfer cortical thickness measurements. Neuroimag, 2014, 99, 166-79](https://linkinghub.elsevier.com/retrieve/pii/S1053-8119(14)00409-1)
3. [Avants, B.B.; Tustison, N.J.; Wu, J.; Cook, P.A.; Gee, J.C. An open source multivariate framework for n-tissue segmentation with evaluation on public data. Neuroinformatics. 2011, 9(4), 381-400](https://link.springer.com/article/10.1007%2Fs12021-011-9109-y)
4. [Wang, H.; Das, S.R.; Suh, J.W.; Altinay, M.; Pluta, J.; Craige, C.; Avants, B.; Yushkevich, P.A. A learning-based wrapper method to correct systematic errors in automatic image segmentation: consistently improved performance in hippocampus, cortex and brain segmentation. Neuroimage, 2011 ,55(3), 968-85](https://www.sciencedirect.com/science/article/pii/S1053811911000243?via%3Dihub)

### ***Others***
1. [Gorgolewski, K., Auer, T., Calhoun, V. D.,  Craddock, R. C., Das, S., Duff, E. P., Flandin, G., Ghosh, S. S.,  Glatard, T., Halchenko, Y.O., Handwerker, D. A., Hanke, M., Keator, D., Li, X., Michael, Z., Maumet, C., Nichols, B. N., Nichols, T. E., Pellman, J., Poline, J-B., Rokem, A., Schaefer, G., Sochat, V., Triplett, W., Turner, J. A., Varoquaux, G., Poldrack, R. A. The brain imaging data structure, a format for organizing and describing outputs of neuroimaging experiments. Scientific Data, 2016,  3, 160044](https://www.nature.com/articles/sdata201644)
2.  [Vos S.B.; Tax C.M.; Luijten P.R.; Ourselin S.; Leemans A.; Froeling M. The importance of correcting for signal drift in diffusion MRI. Magn Reson Med. 2017, 77(1), 285-299](https://doi.org/10.1002/mrm.26124)
3. [Basser, P.J.; Mattiello, J; LeBihan, D; Estimation of the effective self-diffusion tensor from the NMR spin echo. Journal of Magnetic Resonance, Series B, 1994, 103(3), 247-254](https://www.sciencedirect.com/science/article/pii/S1064186684710375)
