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
* *MRtrix3*


Complete Tutorial
================================================================================

Usage
e.g. PreMain -p <OutputPath> -b <BIDSdir>



