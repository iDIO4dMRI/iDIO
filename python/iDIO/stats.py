#!/usr/bin/python
# version:  2021/09/10
# Credit : Modify from PreQual: https://github.com/MASILab/PreQual (by Leon Cai and Qi Yang, MASI Lab, Vanderbilt University)
# iDIO QC stats function

import os, glob

import nibabel as nib
import numpy as np

from scipy import ndimage

# iDIO combined PreQual libraries
import utils
from vars import SHARED_VARS

def BPV_mask(mask_file, subj_dir, temp_dir):
    # Erode brain mask (T1) without CSF
    temp_dir = utils.make_dir(temp_dir, 'MASK')

    # Load T1_mask
    mask_img, mask_aff, _ = utils.load_nii(mask_file, dtype='bool', ndim=3)
    
    # Isolate CSF from 4_T1preproc info in T1 space
    csf_t1_file = subj_dir + '/4_T1preproc/T1w-deGibbs-BiasCo-Brain_pve_0.nii.gz'
    csf_dwi_file = temp_dir + '/csfindwispace.nii.gz'
    init_matrix = subj_dir + '/4_T1preproc/Reg_matrix/str2epi.mat' 
    ref_file = subj_dir + '/4_T1preproc/Average_b0-brain.nii.gz'

    # Convert CSF file in dwispace
    applywarp_cmd = 'flirt -in {} -ref {} -out {} -init {} -applyxfm'.format(csf_t1_file, ref_file, csf_dwi_file, init_matrix)
    utils.run_cmd(applywarp_cmd)

    csf_img = nib.load(csf_dwi_file).get_data()
    # Calculate average CSF probability, call it positive if > 15%
    csf_img = csf_img > 0.15

    # Stats mask = brain without CSF
    BPV_mask_file = os.path.join(temp_dir, 'BPV_mask.nii.gz') # BPV = brain parenchymal volume
    BPV_mask_img = np.logical_and(_erode_mask(mask_img), np.logical_not(csf_img))
    utils.save_nii(BPV_mask_img, mask_aff, BPV_mask_file, dtype='int')

    # Clean Up
    # print('CLEANING UP TEMP DIRECTORY')
    # utils.remove_dir(temp_dir)

    return BPV_mask_file

def chisq(dwi_file, dwi_recon_file, chisq_mask_file, stats_dir):

    print('PERFORMING CHI-SQUARED ANALYSIS ON TENSOR-RECONSTRUCTED SIGNAL')

    # Load data and prep outputs

    dwi_img, _, _ = utils.load_nii(dwi_file, ndim=4)
    dwi_recon_img, _, _ = utils.load_nii(dwi_recon_file, ndim=4)
    chisq_mask_img, _, _ = utils.load_nii(chisq_mask_file, dtype='bool', ndim=3)

    num_slices = dwi_img.shape[2]
    num_vols = dwi_img.shape[3]

    chisq_matrix = np.zeros((num_slices, num_vols))

    # Perform slice-modified pixel chisquared analysis

    for i in range(num_slices):

        for j in range(num_vols):

            dwi_slice = dwi_img[:, :, i, j]
            dwi_slice[np.logical_not(chisq_mask_img[:, :, i])] = 0

            fit_slice = dwi_recon_img[:, :, i, j]
            fit_slice[np.logical_not(chisq_mask_img[:, :, i])] = 0

            ss_error = np.nansum(np.square(dwi_slice - fit_slice)) # sum squared error
            ss_slice = np.nansum(np.square(dwi_slice)) # sum squared slice

            if ss_slice == 0: # all NaN slice
                chisq = np.nan
            else:
                chisq = ss_error / ss_slice # because reported as a ratio, should be larger for larger bvals (b/c they have lower image intensities so ss_slice will be smaller)

            chisq_matrix[i, j] = chisq

    # Save values

    chisq_matrix_file = os.path.join(stats_dir, 'chisq_matrix.txt')
    utils.save_txt(chisq_matrix, chisq_matrix_file)

    return chisq_matrix_file

def motion(eddy_dir, stats_dir):

    # Load motion data

    eddy_params_file = glob.glob(eddy_dir + '/*.eddy_parameters')
    eddy_rms_file = glob.glob(eddy_dir + '/*.eddy_movement_rms')

    eddy_params = utils.load_txt(eddy_params_file[0])
    eddy_rms = utils.load_txt(eddy_rms_file[0])
    # Calculate movement metrics

    rotations = eddy_params[:, 3:6] / np.pi * 180
    avg_rotations = np.nanmean(rotations, axis=0)

    translations = eddy_params[:, 0:3]
    avg_translations = np.nanmean(translations, axis=0)

    abs_displacement = eddy_rms[:, 0]
    avg_abs_displacement = np.array([np.nanmean(abs_displacement)])
    rel_displacement = eddy_rms[:, 1]
    avg_rel_displacement = np.array([np.nanmean(rel_displacement)])

    # Save to dictionary

    motion_dict = {
        'rotations': rotations,
        'translations': translations,
        'abs_displacement': abs_displacement,
        'rel_displacement': rel_displacement,
        'eddy_avg_rotations': avg_rotations,
        'eddy_avg_translations': avg_translations,
        'eddy_avg_abs_displacement': avg_abs_displacement,
        'eddy_avg_rel_displacement': avg_rel_displacement
    }

    # Write to file

    for key in motion_dict:
        if key[0:8] == 'eddy_avg':
            motion_file = os.path.join(stats_dir, '{}.txt'.format(key))
            utils.save_txt(motion_dict[key], motion_file)

    # Format for consolidated dictionary (XNAT)

    stats_out_list = [
        'eddy_avg_rotations_x,{}'.format(avg_rotations[0]),
        'eddy_avg_rotations_y,{}'.format(avg_rotations[1]),
        'eddy_avg_rotations_z,{}'.format(avg_rotations[2]),
        'eddy_avg_translations_x,{}'.format(avg_translations[0]),
        'eddy_avg_translations_y,{}'.format(avg_translations[1]),
        'eddy_avg_translations_z,{}'.format(avg_translations[2]),
        'eddy_avg_abs_displacement,{}'.format(avg_abs_displacement[0]),
        'eddy_avg_rel_displacement,{}'.format(avg_rel_displacement[0])
    ]

    return motion_dict, stats_out_list

def eddy_current(eddy_dir, stats_dir):

    # Load motion data

    eddy_params_file = glob.glob(eddy_dir + '/*.eddy_parameters')
    eddy_params = utils.load_txt(eddy_params_file[0])
    
    # Calculate movement metrics
    EC_linear = eddy_params[:,6:9]
    EC_linear_std = np.std(eddy_params[:,6:9], axis=0)
    # Save to dictionary

    EC_dict = {
        'eddy_linear_x': EC_linear[:,0],
        'eddy_linear_y': EC_linear[:,1],
        'eddy_linear_z': EC_linear[:,2]
    }

    # Format for consolidated dictionary (XNAT)

    stats_out_list = [
        'std_eddy_linear_x,{}'.format(EC_linear_std[0]),
        'std_eddy_linear_y,{}'.format(EC_linear_std[1]),
        'std_eddy_linear_z,{}'.format(EC_linear_std[2]),
    ]

    return EC_dict, stats_out_list



def cnr(bvals_file, mask_file, eddy_dir, stats_dir, shells=[]):

    # Load CNR data

    bvals = utils.load_txt(bvals_file, txt_type='bvals')
    bvals_unique = np.sort(np.unique(bvals))
    eddy_cnr_file = glob.glob(eddy_dir + '/*.eddy_cnr_maps.nii.gz')
    eddy_cnr_img, _, _ = utils.load_nii(eddy_cnr_file[0], ndim=4)
    mask_img, _, _ = utils.load_nii(mask_file, dtype='bool', ndim=3)

    # Check that the number of shells in eddy CNR output and bvals are the same

    cnr_warning_str = ''

    if not len(bvals_unique) == eddy_cnr_img.shape[3]:
        print('NUMBER OF UNIQUE B-VALUES AFTER PREPROCESSING IS NOT EQUAL TO THE NUMBER OF SHELLS DETERMINED BY EDDY. {} FOR SHELL-WISE SNR/CNR ANALYSIS.'.format('ATTEMPTING TO ROUND B-VALUES TO NEAREST 100' if len(shells) == 0 else 'MATCHING B-VALUES TO NEAREST SUPPLIED SHELL'))
        bvals_rounded = []
        for bval in bvals:
            if len(shells) > 0:
                bvals_rounded.append(utils.nearest(bval, shells))
            else:
                bvals_rounded.append(utils.round(bval, 100))
        bvals_unique = np.sort(np.unique(bvals_rounded))
        bvals = bvals_rounded # will need to return bvals "shelled" for visualization of the volumes to match the SNR/CNR shells
        cnr_warning_str = 'For SNR/CNR analysis, the number of unique b-values after preprocessing was not equal to the number of shells determined by eddy. B-values were {} for analysis in an attempt to match eddy.'.format('rounded to the nearest 100' if len(shells) == 0 else 'matched to nearest supplied shell')
    
    # if not len(bvals_unique) == eddy_cnr_img.shape[3]:
    #     raise utils.DTIQAError('NUMBER OF UNIQUE B-VALUES AFTER PREPROCESSING AND ROUNDING TO NEAREST 100 IS NOT EQUAL TO THE NUMBER OF SHELLS DETERMINED BY EDDY. PLEASE ENSURE YOUR DATA IS PROPERLY SHELLED. EXITING.')

    # Calculate SNR/CNR

    cnr_dict = {}
    cnrs = []
    for i in range(len(bvals_unique)):
        eddy_cnr_vol = eddy_cnr_img[..., i]
        if np.sum(eddy_cnr_vol) == 0:
            cnr = np.nan
        else:
            cnr = np.nanmedian(eddy_cnr_vol[mask_img])
        cnr_dict[bvals_unique[i]] = cnr
        cnrs.append([bvals_unique[i], cnr])
    cnrs = np.array(cnrs)

    # Save to file
    # cnr_file = os.path.join(stats_dir, 'eddy_median_cnr.txt')
    # utils.save_txt(cnrs, cnr_file)

    # Format for consolidated dictionary (XNAT)

    stats_out_list = []
    for i in range(0, len(bvals_unique)):
        stats_out_list.append('b{}_median_{},{}'.format(bvals_unique[i], 'snr' if bvals_unique[i] == 0 else 'cnr', cnrs[i][1]))

    return cnr_dict, bvals, stats_out_list, cnr_warning_str

def stats_out(drift_stats_out, motion_stats_out_list, EC_stats_out_list, cnr_stats_out_list, outlier_percentage, percent_improbable, stats_dir):
    
    print('WRITING STATS TO CSV...')
    
    stats_out_list = []
    if os.path.exists(drift_stats_out):
        dr=utils.load_drift(drift_stats_out)       
        stats_out_list.append('Drift_percentage (%),{}'.format(str(dr[0])))
    stats_out_list.append('Improbable voxels (%),{}'.format(percent_improbable))
    stats_out_list.append('\n'.join(motion_stats_out_list))
    stats_out_list.append('\n'.join(EC_stats_out_list))
    stats_out_list.append('Outlier_percantage_total (%),{}'.format(str(outlier_percentage*100)))
    stats_out_list.append('\n'.join(cnr_stats_out_list))
    stats_out_str = '\n'.join(stats_out_list)

    utils.write_str(stats_out_str, os.path.join(stats_dir, 'stats.csv'))

def scalar_info(fa_file, stats_dir, template_dir):

    print('REGISTRATION : SEARCHING THE LOCATION OF CORPUS CALLOSUM')

    temp_dir = utils.make_dir(stats_dir, 'TEMP')
    template_file = os.path.join(template_dir, 'JHU-ICBM-FA-1mm.nii.gz')
    Atlas_file = os.path.join(template_dir, 'JHU-ICBM-labels-1mm.nii.gz')

    subj2template_prefix = os.path.join(temp_dir, 'fa2template_')
    subj_file = fa_file
    
    print('REGISTERING ATLAS TO PATIENT SPACE') # https://github.com/ANTsX/ANTs/wiki/Forward-and-inverse-warps-for-warping-images,-pointsets-and-Jacobians

    reg_cmd = 'antsRegistrationSyNQuick.sh -d 3 -f {} -m {} -n {} -o {}'.format(template_file, subj_file, SHARED_VARS.NUM_THREADS, subj2template_prefix)
    utils.run_cmd(reg_cmd)

    atlas2subj_file = os.path.join(stats_dir, 'atlas2subj.nii.gz')

    applyreg_cmd = 'antsApplyTransforms -d 3 -i {} -r {} -n NearestNeighbor -t [{},1] -t {} -o {}'.format(Atlas_file, subj_file, '{}0GenericAffine.mat'.format(subj2template_prefix), '{}1InverseWarp.nii.gz'.format(subj2template_prefix), atlas2subj_file)
    utils.run_cmd(applyreg_cmd)

    utils.move_file('{}0GenericAffine.mat'.format(subj2template_prefix), stats_dir)
    utils.move_file('{}1Warp.nii.gz'.format(subj2template_prefix), stats_dir)
    utils.move_file('{}1InverseWarp.nii.gz'.format(subj2template_prefix), stats_dir)

    # Localize CC for visualization
    atlas2subj_img, _, _ = utils.load_nii(atlas2subj_file, ndim=3)
    cc_genu_val = 3 # taken from label.txt
    cc_splenium_val = 5
    cc_index = np.logical_or(atlas2subj_img == cc_genu_val, atlas2subj_img == cc_splenium_val)
    cc_locs = np.column_stack(np.where(cc_index))
    cc_center_voxel = (np.nanmean(cc_locs[:, 0]), np.nanmean(cc_locs[:, 1]), np.nanmean(cc_locs[:, 2]))

    # print('CLEANING UP TEMP DIRECTORY')
    utils.remove_dir(temp_dir)

    return atlas2subj_file, cc_center_voxel

def gradcheck(dwi_file, bvals_file, bvecs_file, mask_file, corr_dir):

    dwi_prefix = utils.get_prefix(dwi_file)

    print('CHECKING GRADIENTS FOR {}'.format(dwi_prefix))

    temp_dir = utils.make_dir(corr_dir, 'TEMP')

    corrected_bvals_file = os.path.join(corr_dir, '{}.bval'.format(dwi_prefix))
    corrected_bvecs_file = os.path.join(corr_dir, '{}.bvec'.format(dwi_prefix))

    if os.path.exists(corrected_bvals_file): # dwigradcheck bug: does not force overwrite of output files with -force flag
        print('CORRECTED BVALS FILE ALREADY EXISTS, COMPENSATING FOR DWIGRADCHECK BUG (FAILS TO OVERWRITE)')
        utils.remove_file(corrected_bvals_file)
    if os.path.exists(corrected_bvecs_file):
        print('CORRECTED BVECS FILE ALREADY EXISTS, COMPENSATING FOR DWIGRADCHECK BUG (FAILS TO OVERWRITE)')
        utils.remove_file(corrected_bvecs_file)

    gradcheck_cmd = 'dwigradcheck {} -fslgrad {} {} -export_grad_fsl {} {} -mask {} -scratch {} -force -nthreads {}'.format(dwi_file, bvecs_file, bvals_file, corrected_bvecs_file, corrected_bvals_file, mask_file, temp_dir, SHARED_VARS.NUM_THREADS-1)
    utils.run_cmd(gradcheck_cmd)

    print('CLEANING UP TEMP DIRECTORY')
    utils.remove_dir(temp_dir)

    return corrected_bvals_file, corrected_bvecs_file

# Helper Functions

def _erode_mask(mask_img):

    for i in range(mask_img.shape[2]):
        mask_img[:, :, i] = ndimage.binary_erosion(mask_img[:, :, i], structure=np.ones((3, 3)))
    return mask_img