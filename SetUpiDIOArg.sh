#!/bin/bash

##########################################################################################################################
## Diffusion data processing pipeline
## Written by Kuantsen Kuo
## Version 1.0 2021/02/03
##########################################################################################################################
#
# SetUpOGIOArg.sh
#
# Edit as needed for your specific setup.
# The defaults should work with most installations.

# Set the process you need. [default=1.2.3.4.5.6.7.8]
# Step=1.2.3.4.5.6.7.8
Step=6.7.8
# 1: 1_DWIprep
# 2: 2_BiasCo
# 3: 3_EddyCo
# 4: 4_T1preproc
# 5: 5_DTIFIT
# 6: 6_CSDpreproc
# 7: 7_NetworkProc
# 8: run_iDIOQC

# 1_DWIprep:If your json file have no "SeriesNumber" tag, 
#		 	indicate the scan order first=<first scan filename>.nii.gz, second=<second scan filename>.nii.gz
first=
second=

# 2_BiasCo: 
driftco=0

# 3_EddyCo: Using CUDA to speed up. NVIDIA GPU with CUDA version (8.0/9.1/10.2) is available to use this option. [true=1 / false=0]
# cuda_ver=$(nvcc --version | grep release | cut -d ' ' -f 5 | sed 's/,//g') for CUDA version check
cuda=0

# 3_EddyCo: Slice-to-vol motion correction.
#           This option is only implemented for the CUDA version(cuda=1). [true=1 / false=0]
#           if stv is apply, you can define the parameter for s2v_lambda[defult = 1] /s2v_niter [defult = 5]
#           input 0 -> using default setting
stv=0
s2v_lambda=0
s2v_niter=0


# 3_EddyCo: Resize dwi image intp isotropic voxels (mm) by given value [values / false=0]
# apply for 3_EddyCo  [defult = 0 ]
rsimg=0

# 2_BiasCo, 3_EddyCo, 5_DTIFIT, 6_CSDpreproc, 8_QC: Bzero threshold. [default=10]
bzero=10

# 4_T1preproc, 7_NetworkProc, 8_QC: Set input Atlas directory. [default=${HOGIO}/share]
AtlasDir=${iDIO_HOME}/share

# 6_CSDproc: to run mtnormalise or not. [ture=1 / false=0]
mtnormalise=0

# 7_NetworkProc: Set track select number. [default=10M]
trkNum=10000

