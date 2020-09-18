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

Usage
e.g. PreMain -p <OutputPath> -b <BIDSdir>



