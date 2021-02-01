OGIO
================================================================================

OGIO is a software toolkit for processing diffusion-weighted MRI data. It integrates the functionalities of modern MRI software packages to constitue a complete data processing pipeline for structural connectivity analysis of the human brain.


Installation Guide
================================================================================

OGIO can be run in Linux and macOS systems. Its major functionalities come from *FSL*, *MRtrix3*, and *ANTS*, and therefore these software tools and their relevant dependencies need to be installed before using OGIO. Please check the links below for the installation of them:

* *FSL 6.0.3*: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki
* *MRtrix3*: https://www.mrtrix.org/
* *ANTS*: https://github.com/ANTsX/ANTs/wiki

Currently, OGIO also relies on *MATLAB* to perform one specific bias in DWI data (namely DWI signal drifting) and thus requires a few functions of SPM12. To install *MATLAB* and *SPM12*, please see the links below for instructions:

* *MATLAB*: https://www.mathworks.com/products/matlab.html
* *SPM12*: https://www.fil.ion.ucl.ac.uk/spm/software/spm12/

Setting
* $export HOGIO=pipeline location
* need to save configure file(T1_2_ICBM_MNI152_1mm.cnf in ${HOGIO}/share/MNI) to /usr/local/fsl/etc/flirtsch
* need to save MNI template (mni_icbm152_t1_tal_nlin_asym_09c_/bet/mask.nii.gz in ${HOGIO}/share/MNI) to /usr/local/fsl/data/standard


References
================================================================================

Please cite the following articles if *OGIO* is utilised in your research publications:

* *FSL*
Jenkinson, M.; Beckmann, C.F.; Behrens, T.E.; Woolrich, M.W.; Smith. S.M.; FSL. NeuroImage, 2012, 62:782-90
Smith, S. M. Fast robust automated brain extraction. Human Brain Mapping, 2002, 17, 143-155
Zhang, Y.; Brady, M. & Smith, S. Segmentation of brain MR images through a hidden Markov random field model and the expectation-maximization algorithm. IEEE Transactions on Medical Imaging, 2001, 20, 45-57
Patenaude, B.; Smith, S. M.; Kennedy, D. N. & Jenkinson, M. A Bayesian model of shape and appearance for subcortical brain segmentation. NeuroImage, 2011, 56, 907-922
Smith, S. M.; Jenkinson, M.; Woolrich, M. W.; Beckmann, C. F.; Behrens, T. E.; Johansen-Berg, H.; Bannister, P. R.; De Luca, M.; Drobnjak, I.; Flitney, D. E.; Niazy, R. K.; Saunders, J.; Vickers, J.; Zhang, Y.; De Stefano, N.; Brady, J. M. & Matthews, P. M. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 2004, 23, S208-S219


* *MRtrix3*
Tournier, J.-D.; Smith, R. E.; Raffelt, D.; Tabbara, R.; Dhollander, T.; Pietsch, M.; Christiaens, D.; Jeurissen, B.; Yeh, C.-H. & Connelly, A. MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. NeuroImage, 2019, 202, 116137
Zhang, Y.; Brady, M. & Smith, S. Segmentation of brain MR images through a hidden Markov random field model and the expectation-maximization algorithm. IEEE Transactions on Medical Imaging, 2001, 20, 45-57
Smith, S. M.; Jenkinson, M.; Woolrich, M. W.; Beckmann, C. F.; Behrens, T. E.; Johansen-Berg, H.; Bannister, P. R.; De Luca, M.; Drobnjak, I.; Flitney, D. E.; Niazy, R. K.; Saunders, J.; Vickers, J.; Zhang, Y.; De Stefano, N.; Brady, J. M. & Matthews, P. M. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 2004, 23, S208-S219
Dhollander, T.; Mito, R.; Raffelt, D. & Connelly, A. Improved white matter response function estimation for 3-tissue constrained spherical deconvolution. Proc Intl Soc Mag Reson Med, 2019, 555
Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. Anatomically-constrained tractography: Improved diffusion MRI streamlines tractography through effective use of anatomical information. NeuroImage, 2012, 62, 1924-1938
Jeurissen, B; Tournier, J-D; Dhollander, T; Connelly, A & Sijbers, J. Multi-tissue constrained spherical deconvolution for improved analysis of multi-shell diffusion MRI data. NeuroImage, 2014, 103, 411-426
Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography. NeuroImage, 2015, 119, 338-351
Tournier, J.-D.; Calamante, F. & Connelly, A. Improved probabilistic streamlines tractography by 2nd order integration over fibre orientation distributions. Proceedings of the International Society for Magnetic Resonance in Medicine,
Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography. NeuroImage, 2015, 119, 338-351
Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. The effects of SIFT on the reproducibility and biological accuracy of the structural connectome. NeuroImage, 2015, 104, 253-265
Hagmann, P.; Cammoun, L.; Gigandet, X.; Meuli, R.; Honey, C.; Wedeen, V. & Sporns, O. Mapping the Structural Core of Human Cerebral Cortex. PLoS Biology 6(7), e159

Complete Tutorial
================================================================================
Data preparing: images have to include DWI data and T1 data
(1) DICOM images as inputs - run 0_dcm2bids.sh first

0_dcm2bids.sh
Synopsis
automatically convert the DICOM file into ${BIDSDir}/dwi and ${BIDSDir}/anat directory

Usage
sh 0_dcm2bids.sh -d <DICOMDir> -b <OutputBIDSD>

*DICOMDIR: the input DICOM (.IMA) images
*OutputBIDS: the output images will save as bids format and rename follow the sequence name

Reference


(2) BIDS format images applied - Converted images save in dwi and anat folder


Main.sh
Synopsis
implement the OGIO pipeline from Step 1 (DWI preprocessing) to Step 6 (Netwrok generation)

Usage
sh Main.sh -bids <InputBIDSdir> -proc <OutputPath> [options]

* -bids InputBIDSdir: datapath that including two directory- anat (T1w.nii.gz/T1w.json) and dwi (dwiPHASE.nii.gz, dwi.bval, dwi.bvec, dwi.json)
* -proc OutputPath: Provide a output path for saving the output processed data

Options
* -cuda: allow eddy to usd an Nvidia GPU if one is available on the system
* -atlas: by default, those atlas will save in the pipeline dictionary(${HOGIO}/share). Please indicate the atlas path if changed location.


1_DWIprep.sh
Synopsis
DWI data preperation (identify phase encoding, generate needed description file)

Usage
sh 1_DWIprep -b <InputBIDSdir> -p <OutputPath> -[options]

* -b InputBIDSdir: datapath that including two directory- anat (T1w.nii.gz/T1w.json) and dwi (dwiPHASE.nii.gz, dwi.bval, dwi.bvec, dwi.json)
* -p OutputPath: Provide a output path for saving the output processed data

Options
* -c C4
* -s PhaseEncode: please provide the number of phase encoding images in following order {PA, AP, LR, RL}

Reference
*


2_BiasCo.sh
Synopsis
implement the gibbs ringing correction, 4D signal denoise and drifting correction 

Usage
sh 2_BiasCo.sh -[options]

Options
* -p ProcPath: the ProcPath has to include the 1_DWIprep folder (includes the converted files) [default = pwd directory]

Reference
*


3_EddyCo.sh
Synopsis
implement the distortion and eddy correction

Usage
sh 3_eddyCo.sh -[options]

Options
* -p ProcPath: the ProcPath has to include the 1_DWIprep and 2_BiasCo folder (includes the converted files). [default = pwd directory]
* -c: using CUDA to accelerate the correction process. Both CUDA v9.1 and v8.0 is available. [default = none]
* -m: with -c, -m is applicable for slice-to-volume motion correction.

Reference
*


4_DTIFIT.sh
Synopsis
Diffusion tensor estimation. Only low-b (b<1500 s/mm^2) images were used for further fitting.

Usage
sh 4_DTIFIT.sh -[options]

Options 
* -p ProcPath: the ProcPath has to include the 2_BiasCo and 3_EddyCo folder (includes the converted files). [default = pwd directory]
* -t BzeroThreshold: input the Bzero threshold. [default = 10]

Reference
* Tustison, N.; Avants, B.; Cook, P.; Zheng, Y.; Egan, A.; Yushkevich, P. & Gee, J. N4ITK: Improved N3 Bias Correction. IEEE Transactions on Medical Imaging, 2010, 29, 1310-1320
* Basser, P.J.; Mattiello, J; LeBihan, D; Estimation of the effective self-diffusion tensor from the NMR spin echo. Journal of Magnetic Resonance, Series B, 1994, 103(3), 247-254


5_CSDpreproc.sh 
Synopsis
DWI preprocessing of constrained spherical deconvolution with Dhollanders algorithms

Usage
sh 5_CSDpreproc.sh -[options]

Options
* -p ProcPath: the ProcPath has to include the 3_EddyCo and 4_DTIFIT folder (includes the converted files). [default = pwd directory]
* -t BzeroThreshold: input the Bzero threshold. [default = 10]

Reference
* Smith, S. M. Fast robust automated brain extraction. Human Brain Mapping, 2002, 17, 143-155
* Zhang, Y.; Brady, M. & Smith, S. Segmentation of brain MR images through a hidden Markov random field model and the expectation-maximization algorithm. IEEE Transactions on Medical Imaging, 2001, 20, 45-57
* Patenaude, B.; Smith, S. M.; Kennedy, D. N. & Jenkinson, M. A Bayesian model of shape and appearance for subcortical brain segmentation. NeuroImage, 2011, 56, 907-922
* Smith, S. M.; Jenkinson, M.; Woolrich, M. W.; Beckmann, C. F.; Behrens, T. E.; Johansen-Berg, H.; Bannister, P. R.; De Luca, M.; Drobnjak, I.; Flitney, D. E.; Niazy, R. K.; Saunders, J.; Vickers, J.; Zhang, Y.; De Stefano, N.; Brady, J. M. & Matthews, P. M. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 2004, 23, S208-S219
* Dhollander, T.; Mito, R.; Raffelt, D. & Connelly, A. Improved white matter response function estimation for 3-tissue constrained spherical deconvolution. Proc Intl Soc Mag Reson Med, 2019, 555
* Raffelt, D.; Dhollander, T.; Tournier, J.-D.; Tabbara, R.; Smith, R. E.; Pierre, E. & Connelly, A. Bias Field Correction and Intensity Normalisation for Quantitative Analysis of Apparent Fibre Density. In Proc. ISMRM, 2017, 26, 3541


6_NetworkProc.sh
Synopsis
Generate the tractogram based (anatomical constrained tractography with dynamic seeding and SIFT). Connectivity matrix will be generated with five atlases (AAL3, DK, HCPMMP w/o Subcortical regions, Yeo)

Usage 
sh 6_NetworkProc -[options]

Options
* -p ProcPath: the ProcPath has to include the 5_CSDpreproc folder (includes the converted files). [default = pwd directory]
* -a AtlasDir: the Atlas directory [default = ${HOGIO}/share, need to include Atlas/MNI directories

Reference
* Smith, S. M. Fast robust automated brain extraction. Human Brain Mapping, 2002, 17, 143-155
* Jenkinson, M.; Bannister, P.; Brady, J. M. & Smith, S. M. Improved Optimisation for the Robust and Accurate Linear Registration and Motion Correction of Brain Images. NeuroImage, 2002, 17(2), 825-841
* Tournier, J.-D.; Calamante, F. & Connelly, A. Improved probabilistic streamlines tractography by 2nd order integration over fibre orientation distributions. Proceedings of the International Society for Magnetic Resonance in Medicine, 2010, 1670
* Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. Anatomically-constrained tractography: Improved diffusion MRI streamlines tractography through effective use of anatomical information. NeuroImage, 2012, 62, 1924-1938
* Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography. NeuroImage, 2015, 119, 338-351
* Smith, R. E.; Tournier, J.-D.; Calamante, F. & Connelly, A. The effects of SIFT on the reproducibility and biological accuracy of the structural connectome. NeuroImage, 2015, 104, 253-265
* Hagmann, P.; Cammoun, L.; Gigandet, X.; Meuli, R.; Honey, C.; Wedeen, V. & Sporns, O. Mapping the Structural Core of Human Cerebral Cortex. PLoS Biology 6(7), e159
