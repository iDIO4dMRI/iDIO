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

# Set the process you need. [default=1.2.3.4.5.6.7]
Step=3.4.5.6.7.
# 1: 1_DWIprep
# 2: 2_BiasCo
# 3: 3_EddyCo
# 4: 4_T1preproc
# 5: 5_DTIFIT
# 6: 6_CSDpreproc
# 7: 7_NetworkProc

# 3_EddyCo: Using CUDA to speed up. NVIDIA GPU with CUDA v9.1 is available to use this option. [true=1 / false=0]
cuda=0
# 3_EddyCo: Slice-to-vol motion correction.
#           This option is only implemented for the CUDA version(cuda=1). [true=1 / false=0]
stv=0

# 3_EddyCo: Resize dwi image by .json text file with information about matrix size. [true=1 / false=0]
# apply for 3_EddyCo and further steps
rsimg=1

# 3_EddyCo, 5_DTIFIT, 6_CSDpreproc: Bzero threshold. [default=10]
bzero=10

# 4_T1preproc, 7_NetworkProc: Set input Atlas directory. [default=${HOGIO}/share]
AtlasDir=${HOGIO}/share

# 7_NetworkProc: Set track select number. [default=10M]
trkNum=1000
