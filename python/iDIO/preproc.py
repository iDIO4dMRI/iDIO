#!/usr/bin/python
# version:  2021/09/10
# Credit : Modify from PreQual: https://github.com/MASILab/PreQual (by Leon Cai and Qi Yang, MASI Lab, Vanderbilt University)
# iDIO QC preproc function

# system lib
import sys, os

import nibabel as nib
import numpy as np

# iDIO combined PreQual libraries
import utils
from vars import SHARED_VARS

def tensor(dwi_file, bvals_file, bvecs_file, mask_file, tensor_dir):

    dwi_prefix = utils.get_prefix(dwi_file)

    # print('CONVERTING {} TO TENSOR WITH RECONSTRUCTED SIGNAL...'.format(dwi_prefix))

    tensor_file = os.path.join(tensor_dir, '{}_tensor.nii.gz'.format(dwi_prefix))  # make tensor dwi2tensor then use that for fa tensor2metric, volumes 0-5: D11, D22, D33, D12, D13, D23
    dwi_recon_file = os.path.join(tensor_dir, '{}_recon.nii.gz'.format(dwi_prefix))
    tensor_cmd = 'dwi2tensor {} {} -fslgrad {} {} -mask {} -predicted_signal {} -force -nthreads {}'.format(dwi_file, tensor_file, bvecs_file, bvals_file, mask_file, dwi_recon_file, SHARED_VARS.NUM_THREADS-1)
    utils.run_cmd(tensor_cmd)

    return tensor_file, dwi_recon_file
