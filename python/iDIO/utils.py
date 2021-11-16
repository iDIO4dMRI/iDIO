#!/usr/bin/python
# version:  2021/09/10
# Credit : Modify from PreQual: https://github.com/MASILab/PreQual (by Leon Cai and Qi Yang, MASI Lab, Vanderbilt University)
# iDIO QC utils function

# system lib
import sys, os, subprocess

import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt

from skimage import measure
from scipy.optimize import fmin

# iDIO combined PreQual libraries
from vars import SHARED_VARS

# Class Definitions: dtiQA Error

class DTIQAError(Exception):
    pass

# Function Definitions: General File/NIFTI Management and Command Line Interface
def run_cmd(cmd):

    print('RUNNING: {}'.format(cmd))
    subprocess.check_call(cmd, shell=True)

def run_cmd_output(cmd):
    
    print('RUNNING: {}'.format(cmd))
    output = subprocess.check_output(cmd, shell=True)
    output = output.decode('utf-8')
    output = output.split('\n')[0]
    return output

def copy_file(in_file, out_file):

    cp_cmd = 'cp {} {}'.format(in_file, out_file)
    run_cmd(cp_cmd)

def move_file(in_file, out_file):

    mv_cmd = 'mv {} {}'.format(in_file, out_file)
    run_cmd(mv_cmd)

def rename_file(in_file, out_file):

    move_file(in_file, out_file)

    return out_file

def remove_file(in_file):

    rm_cmd = 'rm {}'.format(in_file)
    run_cmd(rm_cmd)

def remove_dir(in_dir):

    rm_cmd = 'rm -r {}'.format(in_dir)
    run_cmd(rm_cmd)

def make_dir(parent_dir, child_dir):

    new_dir = os.path.join(parent_dir, child_dir)
    if not os.path.exists(new_dir):
        os.mkdir(new_dir)
    return new_dir

def get_prefix(file_path, file_ext='nii'):

    return os.path.split(file_path)[-1].split('.{}'.format(file_ext))[0]

def load_drift(str_file):

    dr =[]
    f = open(str_file)
    dr.append(float(f.read()))

    return dr

def write_str(str_data, str_file):

    with open(str_file, 'w') as str_fobj:
        str_fobj.write(str_data)

def load_txt(txt_file, txt_type=''): 

    txt_data = np.loadtxt(txt_file)
    if txt_type == 'bvals':
        if len(txt_data.shape) == 0:
            txt_data = np.array([txt_data])
    elif txt_type == 'bvecs':
        if len(txt_data.shape) == 1:
            txt_data = np.expand_dims(txt_data, axis=1)
    return txt_data

def save_txt(txt_data, txt_file):

    if len(txt_data.shape) > 2:
        raise DTIQAError('DATA MUST BE A NUMBER OR A 2D ARRAY TO BE SAVED. CURRENT DATA HAS DIMENSION {}.'.format(len(txt_data.shape)))
    if len(txt_data.shape) == 1: # data needs to be in a 2D array to be written (or a number) since bvals need to be written in rows for FSL
        txt_data = np.array([txt_data]) # 0D (i.e. number) or 2D data all fine, concern when data is 1D, it needs to be made 2D.
    np.savetxt(txt_file, txt_data, fmt='%1.7f', delimiter=' ', newline='\n')

def load_nii(nii_file, dtype='', ndim=-1):

    nii = nib.load(nii_file)
    img = nii.get_data()

    if not dtype == '':
        img = img.astype(dtype)
    if len(img.shape) < 3 or len(img.shape) > 4:
        raise DTIQAError('CANNOT LOAD NIFTI IMAGES THAT ARE NOT 3D OR 4D. REQUESTED IMAGE TO LOAD IS {}D.'.format(len(img.shape)))
    if ndim == 3 or ndim == 4:
        if ndim > len(img.shape): # ndim = 4, img = 3
            img = np.expand_dims(img, axis=3)
        elif ndim < len(img.shape): # ndim = 3, img = 4
            if img.shape[-1] == 1:
                img = img[..., 0]
            else:
                raise DTIQAError('CANNOT LOAD NIFTI IMAGE WITH FEWER DIMENSIONS THAT IT ALREADY HAS. REQUESTED {} DIMS, HAS {} DIMS'.format(ndim, len(img.shape)))

    img = np.array(img)
    aff = nii.affine
    hdr = nii.get_header()

    return img, aff, hdr

def save_nii(img, aff, nii_file, dtype='', ndim=-1):

    if not dtype == '':
        img = img.astype(dtype)
    if len(img.shape) < 3 or len(img.shape) > 4:
        raise DTIQAError('CANNOT SAVE NIFTI IMAGES THAT ARE NOT 3D OR 4D. REQUESTED IMAGE TO SAVE IS {}D.'.format(len(img.shape)))
    if ndim == 3 or ndim == 4:
        if ndim > len(img.shape): # ndim = 4, img = 3
            img = np.expand_dims(img, axis=3)
        elif ndim < len(img.shape): # ndim = 3, img = 4
            if img.shape[-1] == 1:
                img = img[..., 0]
            else:
                raise DTIQAError('CANNOT SAVE NIFTI IMAGE WITH FEWER DIMENSIONS THAT IT ALREADY HAS. REQUESTED {} DIMS, HAS {} DIMS'.format(ndim, len(img.shape)))

    nii = nib.Nifti1Image(img, aff)
    nib.save(nii, nii_file)


# Function Definitions: Visualization
def slice_nii(nii_file, offsets=[0], custom_aff=[], min_percentile=0, max_percentile=100, min_intensity=np.nan, max_intensity=np.nan):

    img, aff, hdr = load_nii(nii_file, ndim=3)

    # Extract voxel dimensions and reorient image in radiological view

    vox_dim = hdr.get_zooms()
    if len(custom_aff) > 0:
        aff = custom_aff
    img, vox_dim = _radiological_view(img, aff, vox_dim)

    # Extract min and max of entire volume so slices can be plotted with homogenous scaling

    if np.isnan(min_intensity):
        img_min = np.nanpercentile(img, min_percentile)
    else:
        img_min = min_intensity
        
    if np.isnan(max_intensity):
        img_max = np.nanpercentile(img, max_percentile)
    else:
        img_max = max_intensity

    # Extract center triplanar slices with offsets.

    i0 = int(round(img.shape[0] / 2, 1))
    i1 = int(round(img.shape[1] / 2, 1))
    i2 = int(round(img.shape[2] / 2, 1))

    i0s = []
    i1s = []
    i2s = []
    for offset in offsets:
        i0s.append(i0 + offset)
        i1s.append(i1 + offset)
        i2s.append(i2 + offset)

    s0s = img[i0s, :, :]
    s1s = img[:, i1s, :]
    s2s = img[:, :, i2s]

    slices = (s0s, s1s, s2s)

    # Output Descriptions:
    # slices: a list of sagittal, coronal, and axial volumes.
    # - slices[1] gives the coronal volume
    # - slices[1][:, 0, :] gives the first coronal slices offset offsets[0] from the center coronal slice
    # - np.rot90(np.squeeze(slices[1][:, 0, :])) prepares it for plotting
    # vox_dim: a list of 3 values corresponding to the real-life sizes of each voxel, needed for proper axis scaling when plotting slices
    # img_min and img_max: the min and max values of the img volume, needed for proper homogenous intensity scaling when plotting different slices

    return slices, vox_dim, img_min, img_max

def plot_slice(slices, img_dim, offset_index, vox_dim, img_min, img_max, alpha=1, cmap='gray'):

    s = slices[img_dim]
    if img_dim == 0:
        s = s[offset_index, :, :]
        vox_ratio = vox_dim[2]/vox_dim[1]
    elif img_dim == 1:
        s = s[:, offset_index, :]
        vox_ratio = vox_dim[2]/vox_dim[0]
    elif img_dim == 2:
        s = s[:, :, offset_index]
        vox_ratio = vox_dim[1]/vox_dim[0]
    s = np.rot90(np.squeeze(s))
    im = plt.imshow(s, cmap=cmap, vmin=img_min, vmax=img_max, aspect=vox_ratio, alpha=alpha)
    plt.xticks([], [])
    plt.yticks([], [])
    return im

def plot_slice_contour(slices, img_dim, offset_index, color):

    s = slices[img_dim]
    if img_dim == 0:
        s = s[offset_index, :, :]
    elif img_dim == 1:
        s = s[:, offset_index, :]
    elif img_dim == 2:
        s = s[:, :, offset_index]
    s = np.rot90(np.squeeze(s))
    
    slice_contours = measure.find_contours(s, 0.9)
    for slice_contour in enumerate(slice_contours):
        plt.plot(slice_contour[1][:,1], slice_contour[1][:,0], linewidth=1, color=color)

def plot_slice_iDIO(slices, img_dim, offset_index, vox_dim):

    s = slices[img_dim]
    if img_dim == 0:
        s = s[offset_index, :, :]
        vox_ratio = vox_dim[2]/vox_dim[1]
    elif img_dim == 1:
        s = s[:, offset_index, :]
        vox_ratio = vox_dim[2]/vox_dim[0]
    elif img_dim == 2:
        s = s[:, :, offset_index]
        vox_ratio = vox_dim[1]/vox_dim[0]
    s = np.rot90(np.squeeze(s))
    
    return s, vox_ratio

def plot_slice_contour_iDIO(slices, img_dim, offset_index):

    s = slices[img_dim]
    if img_dim == 0:
        s = s[offset_index, :, :]
    elif img_dim == 1:
        s = s[:, offset_index, :]
    elif img_dim == 2:
        s = s[:, :, offset_index]
    s = np.rot90(np.squeeze(s))
    slice_contours = measure.find_contours(s, 0.9)

    return slice_contours

def merge_pdfs(pdf_files, merged_prefix, pdf_dir):

    print('MERGING PDFS')

    pdf_files_str = ' '.join(pdf_files)
    merged_pdf_file = os.path.join(pdf_dir, '{}.pdf'.format(merged_prefix))
    gs_cmd = 'gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE={} -dBATCH {}'.format(merged_pdf_file, pdf_files_str)
    run_cmd(gs_cmd)

    # print('CLEANING UP COMPONENT PDFS')
    remove_file(pdf_files_str)

    return merged_pdf_file

def radiological_order(aff):
    
    orientations = nib.orientations.io_orientation(aff) # Get orientations relative to RAS in nibabel
    old_axis_order = np.array(orientations[:, 0]) # Permute to get RL, AP, IS axes in right order
    new_axis_order = np.array([0, 1, 2])
    permute_axis_order = list(np.array([new_axis_order[old_axis_order == 0],
                                        new_axis_order[old_axis_order == 1],
                                        new_axis_order[old_axis_order == 2]]).flatten())
    return permute_axis_order

def Residual(in_file, sub_file, res_file):
    
    tmp = os.path.splitext(os.path.splitext(res_file)[0])[0]
    res_mean_file = tmp + '_mean.nii.gz'
    res_cmd = 'mrcalc {} {} -subtract {} -force'.format(in_file, sub_file, res_file)
    run_cmd(res_cmd)
    # res_mean_cmd = 'mrmath {} mean {} -axis 3'.format(res_file, res_mean_file)
    # run_cmd(res_mean_cmd)
    return res_file #, res_mean_file

# Function Definitions: Pipeline needs

def load_config(in_dir):

    # load phase info
    config_file = os.path.join(in_dir, '1_DWIprep/Index_PE.txt') # load PE information
    config_mat = np.genfromtxt(config_file, dtype=np.int_)
    # if len(config_mat.shape) == 1:
    #     config_mat = np.expand_dims(config_mat, axis=0)
    # # load totalreadout time info
    # config2_file = os.path.join(in_dir, '1_DWIprep/Acqparams_Topup.txt')
    # config2_mat = np.genfromtxt(config2_file, dtype=np.float_)

    #load dwiprefixes
    PE = ['PA','AP','RL','LR'] #j+,j-,i+,i-
    PEsymbol = ['+','-','+','-']
    PEaxis = ['j','j','i','i']

    dwi_prefixes = []
    pe_dirs = []
    pe_axis = []
    readout_times = []
    prefixes = 'dwi_'
    mergename = 'dwi_'
    for i in range(1,np.size(np.where(config_mat!=0))+1):
        dwi_prefixes.append(prefixes+PE[np.where(config_mat==i)[0][0]])
        pe_dirs.append(PEsymbol[np.where(config_mat==i)[0][0]])
        pe_axis.append(PEaxis[np.where(config_mat==i)[0][0]])
        # readout_times.append(config2_mat[i-1,3])
        mergename = mergename + PE[np.where(config_mat==i)[0][0]]

    mergename = os.path.join(in_dir, '2_BiasCo', mergename + '.nii.gz')
    dwi_dir = os.path.join(in_dir, '0_BIDS_NIFTI')
    dwi_files = []
    bvals_files = []
    bvecs_files = []
    for dwi_prefix in dwi_prefixes:
        dwi_files.append(os.path.join(dwi_dir, '{}.nii.gz'.format(dwi_prefix)))
        bvals_files.append(os.path.join(dwi_dir, '{}.bval'.format(dwi_prefix)))
        bvecs_files.append(os.path.join(dwi_dir, '{}.bvec'.format(dwi_prefix)))

    return dwi_files, bvals_files, bvecs_files, pe_dirs, pe_axis, mergename#readout_times

# Function Definitions: Math Helper Functions
def nearest(value, array):

    array = np.asarray(array)
    idx = (np.abs(array - value)).argmin()
    return array[idx]

def round(num, base):

    d = num / base
    if d % 1 >= 0.5:
        return base*np.ceil(d)
    else:
        return base*np.floor(d)

# Function Definitions: DWI Manipulation
def dwi_extract(dwi_file, bvecs_file, bvals_file, extract_dir, target_bval=0, first_only=False):

    dwi_prefix = get_prefix(dwi_file)

    # print('EXTRACTING {} {} VOLUME(S) FROM {}'.format('FIRST' if first_only else 'ALL', 'B = {}'.format(target_bval), dwi_prefix))

    dwi_img, dwi_aff, _ = load_nii(dwi_file, ndim=4)

    # rounded bvals
    bvals = shell_bvals(dwi_file, bvecs_file, bvals_file)
    # bvals = load_txt(bvals_file, txt_type='bvals')

    num_total_vols = dwi_img.shape[3]
    index = np.array(range(0, num_total_vols))
    index = index[bvals == target_bval]

    if first_only:

        print('EXTRACTING FIRST VOLUME ONLY => 3D OUTPUT')
        dwi_extracted_img = dwi_img[:, :, :, index[0]]
        num_extracted_vols = 1

    else:

        print('EXTRACTING ALL VALID VOLUMES => 4D OUTPUT')
        dwi_extracted_img = dwi_img[:, :, :, index]
        num_extracted_vols = len(index)

    print('EXTRACTED IMAGE HAS SHAPE {}'.format(dwi_extracted_img.shape))

    dwi_extracted_file = os.path.join(extract_dir, '{}_b{}_{}.nii.gz'.format(dwi_prefix, target_bval, 'first' if first_only else 'all'))
    save_nii(dwi_extracted_img, dwi_aff, dwi_extracted_file, ndim=4)

    return dwi_extracted_file, num_extracted_vols, num_total_vols

def dwi_extract_iDIO(dwi_file, bvals, extract_dir, target_bval=0, first_only=False, shells=[]):

    dwi_prefix = get_prefix(dwi_file)

    # print('EXTRACTING {} {} VOLUME(S) FROM {}'.format('FIRST' if first_only else 'ALL', 'B = {}'.format(target_bval), dwi_prefix))

    dwi_img, dwi_aff, _ = load_nii(dwi_file, ndim=4)

    num_total_vols = dwi_img.shape[3]
    index = np.array(range(0, num_total_vols))
    index = index[bvals == target_bval]

    if first_only:

        # print('EXTRACTING FIRST VOLUME ONLY => 3D OUTPUT')
        dwi_extracted_img = dwi_img[:, :, :, index[0]]
        num_extracted_vols = 1

    else:

        # print('EXTRACTING ALL VALID VOLUMES => 4D OUTPUT')
        dwi_extracted_img = dwi_img[:, :, :, index]
        num_extracted_vols = len(index)

    print('EXTRACTED IMAGE HAS SHAPE {}'.format(dwi_extracted_img.shape))

    dwi_extracted_file = os.path.join(extract_dir, '{}_b{}_{}.nii.gz'.format(dwi_prefix, target_bval, 'first' if first_only else 'all'))
    save_nii(dwi_extracted_img, dwi_aff, dwi_extracted_file, ndim=4)

    return dwi_extracted_file, num_extracted_vols, num_total_vols

def dwi_avg(dwi_file, avg_dir):

    dwi_prefix = get_prefix(dwi_file)

    print('AVERAGING {}'.format(dwi_prefix))

    dwi_img, dwi_aff, _ = load_nii(dwi_file, ndim=4)
    dwi_avg_img = np.nanmean(dwi_img, axis=3)
    dwi_avg_file = os.path.join(avg_dir, '{}_avg.nii.gz'.format(dwi_prefix))
    save_nii(dwi_avg_img, dwi_aff, dwi_avg_file, ndim=3)

    return dwi_avg_file

def dwi_merge(dwi_files, merged_prefix, merge_dir):

    merged_dwi_file = os.path.join(merge_dir, '{}.nii.gz'.format(merged_prefix))

    if len(dwi_files) == 1:

        print('ONLY ONE NII FILE PROVIDED FOR MERGING, COPYING AND RENAMING INPUT')
        copy_file(dwi_files[0], merged_dwi_file)

    else:

        print('MORE THAN ONE IMAGE PROVIDED FOR MERGING, PERFORMING MERGE')
        merge_cmd = 'fslmerge -t {} '.format(merged_dwi_file)
        for dwi_file in dwi_files:
            merge_cmd = '{}{} '.format(merge_cmd, dwi_file)
        run_cmd(merge_cmd)

    return merged_dwi_file

def bvals_merge(bvals_files, merged_prefix, merge_dir):

    merged_bvals_file = os.path.join(merge_dir, '{}.bval'.format(merged_prefix))

    if len(bvals_files) == 1:

        print('ONLY ONE BVAL FILE PROVIDED FOR MERGING, COPYING AND RENAMING INPUT')
        copy_file(bvals_files[0], merged_bvals_file)

    else:

        print('MORE THAN ONE BVALS FILE PROVIDED FOR MERGING, PERFORMING MERGE')
        merged_bvals = np.array([])
        for bvals_file in bvals_files:
            merged_bvals = np.hstack((merged_bvals, load_txt(bvals_file, txt_type='bvals')))
        save_txt(merged_bvals, merged_bvals_file)

    return merged_bvals_file

def bvecs_merge(bvecs_files, merged_prefix, merge_dir):

    merged_bvecs_file = os.path.join(merge_dir, '{}.bvec'.format(merged_prefix))

    if len(bvecs_files) == 1:

        print('ONLY ONE BVEC FILE PROVIDED FOR MERGING, COPYING AND RENAMING INPUT')
        copy_file(bvecs_files[0], merged_bvecs_file)

    else:

        print('MORE THAN ONE BVECS FILE PROVIDED FOR MERGING, PERFORMING MERGE')
        merged_bvecs = np.array([[], [], []])
        for bvecs_file in bvecs_files:
            merged_bvecs = np.hstack((merged_bvecs, load_txt(bvecs_file, txt_type='bvecs')))
        save_txt(merged_bvecs, merged_bvecs_file)

    return merged_bvecs_file

def dwi_improbable_mask(mask_file, dwi_file, bvals, mask_dir):

    mask_prefix = get_prefix(mask_file)

    # print('IDENTIFYING VOXELS FOR IMPROBABLE MASK, BUILDING ON EXISTING MASK {}'.format(mask_prefix))

    # Load mask, DWI, and b-values 

    mask_img, mask_aff, _ = load_nii(mask_file, dtype='bool', ndim=3)
    dwi_img, _, _ = load_nii(dwi_file, ndim=4)
    # bvals = load_txt(bvals_file, txt_type='bvals')

    # Keep voxels where the minimum value across b0s is greater than the minimum value across dwis
    # and its in the original mask

    b0_min_img = np.amin(dwi_img[:, :, :, bvals == 0], axis=3)
    dwi_min_img = np.amin(dwi_img[:, :, :, bvals != 0], axis=3)
    improbable_voxels = np.logical_and(b0_min_img < dwi_min_img, mask_img)
    probable_mask_img = np.logical_and(b0_min_img > dwi_min_img, mask_img)

    # Compute Percent of intra-mask voxels that are improbable

    percent_improbable = 100 * (1 - np.sum(probable_mask_img)/np.sum(mask_img))
    print('WITHIN MASK {}, {:.2f}% OF VOXELS WERE IMPROBABLE'.format(mask_prefix, percent_improbable))

    # Save improbable mask

    improbable_voxels_file = os.path.join(mask_dir, '{}_improbable_voxles.nii.gz'.format(mask_prefix))
    save_nii(improbable_voxels.astype(int), mask_aff, improbable_voxels_file, ndim=3)

    probable_mask_file = os.path.join(mask_dir, '{}_probable_mask.nii.gz'.format(mask_prefix))
    save_nii(probable_mask_img.astype(int), mask_aff, probable_mask_file, ndim=3)

    return probable_mask_file, improbable_voxels_file, percent_improbable

def dwi_norm(dwi_files, bvecs_files, bvals_files, norm_dir, B0thr):

    temp_dir = make_dir(norm_dir, 'TEMP')

    dwi_norm_files = []
    gains = []
    imgs = []
    imgs_normed = []

    # Calculate and apply gains to normalize dwi images

    for i in range(len(dwi_files)):

        dwi_prefix = get_prefix(dwi_files[i])

        print('NORMALIZING {}...'.format(dwi_prefix))
        bvals, _, _ = shell_bvals(dwi_files[i], bvecs_files[i], bvals_files[i], B0thr)

        b0s_file, _, _ = dwi_extract_iDIO(dwi_files[i], bvals, temp_dir, target_bval=0, first_only=False)
        b0s_avg_file = dwi_avg(b0s_file, temp_dir)
        mask_file = dwi_mask(b0s_avg_file, temp_dir)

        b0s_avg_img, _, _ = load_nii(b0s_avg_file, ndim=3)
        mask_img, _, _ = load_nii(mask_file, dtype='bool', ndim=3)
        
        img = b0s_avg_img[mask_img]
        if i == 0:
            img_ref = img
            gain = 1
        else:
            img_in = img
            gain = _calc_gain(img_ref, img_in)

        print('GAIN: {}'.format(gain))

        dwi_img, dwi_aff, _ = load_nii(dwi_files[i])
        dwi_norm_img = dwi_img * gain
        dwi_norm_file = os.path.join(norm_dir, '{}_norm.nii.gz'.format(dwi_prefix))
        save_nii(dwi_norm_img, dwi_aff, dwi_norm_file)

        dwi_norm_files.append(dwi_norm_file)
        gains.append(gain)
        imgs.append(list(img))
        imgs_normed.append(list(img * gain))

    # Get average b0 histograms for visualization

    common_min_intensity = 0
    common_max_intensity = 0
    for img in imgs:
        img_max = np.nanmax(img)
        if img_max > common_max_intensity:
            common_max_intensity = img_max
    for img_normed in imgs_normed:
        img_normed_max = np.nanmax(img_normed)
        if img_normed_max > common_max_intensity:
            common_max_intensity = img_normed_max
    bins = np.linspace(common_min_intensity, common_max_intensity, 100)
    
    hists = []
    hists_normed = []
    for i in range(len(imgs)):
        hist, _ = np.histogram(imgs[i], bins=bins)
        hists.append(hist)
        hist_normed, _ = np.histogram(imgs_normed[i], bins=bins)
        hists_normed.append(hist_normed)

    return dwi_norm_files, gains, bins[:-1], hists, hists_normed

def dwi_mask(dwi_file, mask_dir):

    temp_dir = make_dir(mask_dir, 'TEMP')
    
    # Compute bet mask on 3D DWI image

    bet_file = os.path.join(temp_dir, 'bet.nii.gz')
    bet_mask_file = os.path.join(temp_dir, 'bet_mask.nii.gz')
    bet_cmd = 'bet {} {} -f 0.25 -m -n -R'.format(dwi_file, bet_file)
    run_cmd(bet_cmd)

    # Move binary mask out of temp directory

    dwi_prefix = get_prefix(dwi_file)
    mask_file = os.path.join(mask_dir, '{}_mask.nii.gz'.format(dwi_prefix))
    move_file(bet_mask_file, mask_file)

    # Clean up

    remove_dir(temp_dir)

    return mask_file

# load shell numbers -> should write as util function
def shell_bvals(img, bvecs, bvals, bthr, bepsilon=80):
    Raw_b = load_txt(bvals, txt_type='bvals')
    shelled_bvals = Raw_b
    shelled_bvals[shelled_bvals<=10]=0
    shell_indices = run_cmd_output('mrinfo {} -fslgrad {} {} -shell_indices -config BZeroThreshold {} -config BValueEpsilon {}'.format(img, bvecs, bvals, bthr, bepsilon))
    shell_indices = shell_indices.split(' ')
    shell_b = []
    shell_ind = []
    for shell_indice in shell_indices:
        if not len(shell_indice) == 0:
            b_to_use = []
            for x in shell_indice.split(","):
                b_to_use.append(int(x))
            shell_b.append(int(np.median(Raw_b[b_to_use])))
            shell_ind.append(np.array(b_to_use))
            shelled_bvals[b_to_use] = int(np.median(Raw_b[b_to_use]))

    
    return shelled_bvals, np.array(shell_b), shell_ind

# Function Definitions: Phase Encoding Scheme Manipulation
# not to sure whether this is correct, not use now
def pescheme2axis(pe_axis, pe_dir, aff):

    if pe_axis == 'i':
        axis_idx = 0
    elif pe_axis == 'j':
        axis_idx = 1
    else:
        raise DTIQAError('INVALID PHASE ENCODING AXIS SPECIFIED!')

    axis_codes = nib.orientations.aff2axcodes(aff)
    axis_name = axis_codes[axis_idx]

    if pe_dir == '-':
        dir_name = 'From'
    elif pe_dir == '+':
        dir_name = 'To'
    else:
        raise DTIQAError('INVALID PHASE ENCODING DIRECTION SPECIFIED!')

    axis_str = '{} {}'.format(dir_name, axis_name)

    return axis_str

# Helper function
def _radiological_view(img, aff, vox_dim=(1, 1, 1)):

    # RAS defined by nibabel as L->R, P->A, I->S. Orientation functions from nibabel assume this.
    # "Radiological view" is LAS. Want to view in radiological view for doctors.
    # NIFTIs are required to have world coordinates in RAS.

    # Some helpful links:
    # https://users.fmrib.ox.ac.uk/~paulmc/fsleyes/userdoc/latest/display_space.html#radiological-vs-neurological
    # https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Orientation%20Explained

    orientations = nib.orientations.io_orientation(aff) # Get orientations relative to RAS in nibabel

    old_axis_order = np.array(orientations[:, 0]) # Permute to get RL, AP, IS axes in right order
    new_axis_order = np.array([0, 1, 2])
    permute_axis_order = list(np.array([new_axis_order[old_axis_order == 0],
                                        new_axis_order[old_axis_order == 1],
                                        new_axis_order[old_axis_order == 2]]).flatten())
    img = np.transpose(img, axes=permute_axis_order)
    orientations_permute = orientations[permute_axis_order]

    vox_dim = np.array(vox_dim)[permute_axis_order] # Do the same to reorder pixel dimensions

    for orientation in orientations_permute: # Flip axes as needed to get R/A/S as positive end of axis (into radiological view)
        if (orientation[1] == 1 and orientation[0] == 0) or (orientation[1] == -1 and orientation[0] > 0):
            img = nib.orientations.flip_axis(img, axis=orientation[0].astype('int'))
    
    return img, vox_dim

def _calc_gain(img_ref, img_in):

    gain_inits = np.linspace(0.5, 1.5, 10)
    gains = np.zeros(len(gain_inits))
    errors = np.zeros(len(gain_inits))
    for i in range(len(gain_inits)):
        gain, error, _, _, _ = fmin(_err, gain_inits[i], args=(img_ref, img_in), full_output=True)
        gains[i] = gain[0]
        errors[i] = error
    return gains[np.argmin(errors)]