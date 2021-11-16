#!/usr/bin/python
# version:  2021/09/10
# Credit : Modify from PreQual: https://github.com/MASILab/PreQual (by Leon Cai and Qi Yang, MASI Lab, Vanderbilt University)
# iDIO QC vis function

# Set Up
import os, glob

from io import StringIO

import nibabel as nib
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.cm as mcm
import matplotlib.image as mpimg
import matplotlib.text as mtext
from matplotlib.transforms import Affine2D

# import mpl_toolkits.axisartist as axisartist
from skimage import measure

# iDIO combined PreQual libraries
import utils
from vars import SHARED_VARS


# Define Visualization Functions

def vis_pedir(dwi_files, bvecs_files, bvals_files, pe_axis, pe_dirs, vis_dir, B0thr):

    temp_dir = utils.make_dir(vis_dir, 'TMP')

    # fig = plt.figure(0, figsize=SHARED_VARS.PAGESIZE)
    num_dwi = len(dwi_files)
    dwi_prefixes = []
    dwi_pe_strs = []

    tmp, _, tmp_hdr = utils.load_nii(dwi_files[0])
    tmp_vd=tmp_hdr.get_zooms()

    if num_dwi == 1:
        fig, ax = plt.subplots(nrows=3, ncols=num_dwi, gridspec_kw={ 'width_ratios': [1], 'height_ratios': [tmp.shape[2]/tmp_vd[1], tmp.shape[2]/tmp_vd[1], tmp.shape[1]/tmp_vd[2]]})
    else:
        fig, ax = plt.subplots(nrows=3, ncols=num_dwi, gridspec_kw={ 'width_ratios': [1,1], 'height_ratios': [tmp.shape[2]/tmp_vd[1], tmp.shape[2]/tmp_vd[1], tmp.shape[1]/tmp_vd[2]]})

    for i in range(num_dwi):

        dwi_file = dwi_files[i]
        bvals_file = bvals_files[i]
        bvecs_file = bvecs_files[i]

        bvals, _, _ = utils.shell_bvals(dwi_files[i], bvecs_files[i], bvals_files[i], B0thr)

        b0_file, _, _ = utils.dwi_extract_iDIO(dwi_file, bvals, temp_dir, target_bval=0, first_only=True)
        b0_img, b0_aff, _ = utils.load_nii(b0_file)
        b0_slices, b0_vox_dim, b0_min, b0_max = utils.slice_nii(b0_file, min_intensity=0, max_percentile=SHARED_VARS.VIS_PERCENTILE_MAX)
        
        dwi_prefixes.append(utils.get_prefix(dwi_file))
        dwi_pe_strs.append(utils.pescheme2axis(pe_axis[i], pe_dirs[i], b0_aff))

        for j in range(0,3):
            s, vox_ratio=utils.plot_slice_iDIO(slices=b0_slices, img_dim=j, offset_index=0, vox_dim=b0_vox_dim)

            if num_dwi > 1:
                ax[j, i].imshow(s, cmap='gray', vmin=b0_min, vmax=b0_max, aspect=vox_ratio, alpha=1)
                # set tick off
                ax[j, i].set_xticks([])
                ax[j, i].set_yticks([])
                if j == 0:
                    ax[j, i].set_xlabel('P | A', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                    # ax[j, i].set_title('{}) {} ({})'.format(i+1, dwi_prefixes[i], dwi_pe_strs[i]), fontsize=SHARED_VARS.LABEL_FONTSIZE)
                    ax[j, i].set_title('{}) {}'.format(i+1, dwi_prefixes[i]), fontsize=SHARED_VARS.LABEL_FONTSIZE)

                    if i == 0:
                        ax[j, i].set_ylabel('Sagittal', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                elif j== 1:
                    ax[j, i].set_xlabel('R | L', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                    if i == 0:
                        ax[j, i].set_ylabel('Coronal', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                elif j == 2:
                    ax[j, i].set_xlabel('R | L', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                    if i == 0:
                        ax[j, i].set_ylabel('Axial', fontsize=SHARED_VARS.LABEL_FONTSIZE)
            else:
                ax[j].imshow(s, cmap='gray', vmin=b0_min, vmax=b0_max, aspect=vox_ratio, alpha=1)
                # set tick off
                ax[j].set_xticks([])
                ax[j].set_yticks([])
                if j == 0:
                    ax[j].set_xlabel('P | A', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                    # ax[j].set_title('{}) {} ({})'.format(i+1, dwi_prefixes[i], dwi_pe_strs[i]), fontsize=SHARED_VARS.LABEL_FONTSIZE)
                    ax[j].set_title('{}) {}'.format(i+1, dwi_prefixes[i]), fontsize=SHARED_VARS.LABEL_FONTSIZE)
                    ax[j].set_ylabel('Sagittal', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                elif j== 1:
                    ax[j].set_xlabel('R | L', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                    ax[j].set_ylabel('Coronal', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                elif j == 2:
                    ax[j].set_xlabel('R | L', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                    if i == 0:
                        ax[j].set_ylabel('Axial', fontsize=SHARED_VARS.LABEL_FONTSIZE)
                          
    plt.tight_layout()
    plt.subplots_adjust(top=0.9)
    fig.set_size_inches(SHARED_VARS.PAGESIZE)
    plt.suptitle('PE Direction', fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')

    fig.set_size_inches(SHARED_VARS.PAGESIZE)

    pedir_vis_file = os.path.join(vis_dir, 'pedir.pdf')
    plt.savefig(pedir_vis_file)#, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    # utils.remove_dir(temp_dir)

    return pedir_vis_file

def vis_degibbs(dwi_files, bvals, dwi_degibbs_files, gains, vis_dir):

    temp_dir = utils.make_dir(vis_dir, 'TMP')

    # Scale all inputs by prenormalization gains

    dwi_scaled_files = []
    dwi_degibbs_scaled_files = []
    for i in range(len(dwi_files)):
        # Pregibbs
        dwi_prefix = utils.get_prefix(dwi_files[i], file_ext='nii')
        dwi_img, dwi_aff, _ = utils.load_nii(dwi_files[i])
        dwi_scaled_img = dwi_img * gains[i]
        dwi_scaled_file = os.path.join(temp_dir, '{}_scaled.nii.gz'.format(dwi_prefix))
        utils.save_nii(dwi_scaled_img, dwi_aff, dwi_scaled_file)
        dwi_scaled_files.append(dwi_scaled_file)
        
        # Postgibbs
        dwi_degibbs_prefix = utils.get_prefix(dwi_degibbs_files[i], file_ext='nii')
        dwi_degibbs_img, dwi_degibbs_aff, _ = utils.load_nii(dwi_degibbs_files[i])
        dwi_degibbs_scaled_img = dwi_degibbs_img * gains[i]
        dwi_degibbs_scaled_file = os.path.join(temp_dir, '{}_scaled.nii.gz'.format(dwi_degibbs_prefix))
        utils.save_nii(dwi_degibbs_scaled_img, dwi_degibbs_aff, dwi_degibbs_scaled_file)
        dwi_degibbs_scaled_files.append(dwi_degibbs_scaled_file)

    # Load common bvals
    # gibbs_bval_file = utils.bvals_merge(bvals_files, 'gibbs', temp_dir)

    # Load pregibbs b0s, scaled by prenorm gains

    pregibbs_prefix = 'pregibbs_scaled'
    pregibbs_dwi_file = utils.dwi_merge(dwi_scaled_files, pregibbs_prefix, temp_dir)
    pregibbs_b0s_file, _, _ = utils.dwi_extract_iDIO(pregibbs_dwi_file, bvals, temp_dir, target_bval=0, first_only=False)
    pregibbs_b0s_img, gibbs_b0s_aff, _ = utils.load_nii(pregibbs_b0s_file, ndim=4)

    # Load postgibbs b0s, scaled by prenorm gains

    postgibbs_prefix = 'postgibbs_scaled'
    postgibbs_dwi_file = utils.dwi_merge(dwi_degibbs_scaled_files, postgibbs_prefix, temp_dir)
    postgibbs_b0s_file, _, _ = utils.dwi_extract_iDIO(postgibbs_dwi_file, bvals, temp_dir, target_bval=0, first_only=False)
    postgibbs_b0s_img, _, _ = utils.load_nii(postgibbs_b0s_file, ndim=4)

    # Calculate average absolute residuals

    # res_img = np.nanmean(np.abs(postgibbs_b0s_img - pregibbs_b0s_img), axis=3)
    res_img = np.nanmean(postgibbs_b0s_img - pregibbs_b0s_img, axis=3)

    res_aff = gibbs_b0s_aff
    res_file = os.path.join(temp_dir, 'gibbs_residuals.nii.gz')
    utils.save_nii(res_img, res_aff, res_file, ndim=3)

    # Plot 5 central triplanar views

    # res_slices, res_vox_dim, res_min, res_max = utils.slice_nii(res_file, offsets=[-10, -5, 0, 5, 10], min_intensity=0, max_percentile=99)
    # temp_vis_file = vis_vol(res_slices, res_vox_dim, res_min, res_max, temp_dir, name='Gibbs_Deringing,_Averaged_Residuals_of_b_=_0_Volumes', comment='Residuals should be larger at high-contrast interfaces', colorbar=False)
    res_slices, res_vox_dim, res_min, res_max = utils.slice_nii(res_file, offsets=[-10, -5, 0, 5, 10], min_percentile=2, max_percentile=98)
    temp_vis_file = vis_vol(res_slices, res_vox_dim, res_min, res_max, temp_dir, name='Gibbs_Deringing,_Averaged_Residuals_of_b_=_0_Volumes', colorbar=True, cmap='jet')

    degibbs_vis_file = utils.rename_file(temp_vis_file, os.path.join(vis_dir, 'degibbs.pdf'))

    # Finish Up

    # utils.remove_dir(temp_dir)

    return degibbs_vis_file

def vis_vol(slices, vox_dim, min, max, vis_dir, name='?', comment='', colorbar=False, cmap='gray'):

    title = name.replace('_', ' ')
    if not comment == '':
        title = '{}\n({})'.format(title, comment)

    print('VISUALIZING 3D VOLUME: {}'.format(name))

    fig = plt.figure(0, figsize=SHARED_VARS.PAGESIZE)

    for i in range(0, 5):

        plt.subplot(3, 5, i+1)
        utils.plot_slice(slices=slices, img_dim=0, offset_index=i, vox_dim=vox_dim, img_min=min, img_max=max, cmap=cmap)
        if i == 0:
            plt.xlabel('Right Slice', fontsize=SHARED_VARS.LABEL_FONTSIZE)
        if i == 2:
            plt.title('Sagittal', fontsize=SHARED_VARS.LABEL_FONTSIZE)
            plt.xlabel('P | A', fontsize=SHARED_VARS.LABEL_FONTSIZE)
        if i == 4:
            plt.xlabel('Left Slice', fontsize=SHARED_VARS.LABEL_FONTSIZE)

        plt.subplot(3, 5, i+1 + 5)
        utils.plot_slice(slices=slices, img_dim=1, offset_index=i, vox_dim=vox_dim, img_min=min, img_max=max, cmap=cmap)
        if i == 0:
            plt.xlabel('Posterior Slice', fontsize=SHARED_VARS.LABEL_FONTSIZE)
        if i == 2:
            plt.title('Coronal', fontsize=SHARED_VARS.LABEL_FONTSIZE)
            plt.xlabel('R | L', fontsize=SHARED_VARS.LABEL_FONTSIZE)
        if i == 4:
            plt.xlabel('Anterior Slice', fontsize=SHARED_VARS.LABEL_FONTSIZE)

        plt.subplot(3, 5, i+1 + 10)
        im = utils.plot_slice(slices=slices, img_dim=2, offset_index=i, vox_dim=vox_dim, img_min=min, img_max=max, cmap=cmap)
        if i == 0:
            plt.xlabel('Inferior Slice', fontsize=SHARED_VARS.LABEL_FONTSIZE)
        if i == 2:
            plt.title('Axial', fontsize=SHARED_VARS.LABEL_FONTSIZE)
            plt.xlabel('R | L', fontsize=SHARED_VARS.LABEL_FONTSIZE)
        if i == 4:
            plt.xlabel('Superior Slice', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.tight_layout()

    plt.subplots_adjust(top=0.9)
    plt.suptitle('{}'.format(title), fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')

    if colorbar:
        # plt.subplots_adjust(right=0.85)
        cbar_ax = fig.add_axes([0.25, 0.9, 0.5, 0.025])
        plt.colorbar(im, cax=cbar_ax, orientation='horizontal')

    vis_file = os.path.join(vis_dir, '{}.pdf'.format(name))
    plt.savefig(vis_file, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    return vis_file

def vis_preproc_mask(dwi_files, bvecs_files, bvals_files, dwi_preproc_file, bvals_preproc_shelled, eddy_mask_file, mask_file, percent_improbable, stats_mask_file, pe_axis, pe_dirs, vis_dir, B0thr):

    temp_dir = utils.make_dir(vis_dir, 'TMP')

    eddy_mask_slices, _, _, _ = utils.slice_nii(eddy_mask_file)

    num_dwi = len(dwi_files)
    dwi_prefixes = []
    dwi_pe_strs = []
    # plt.figure(0, figsize=SHARED_VARS.PAGESIZE)

    tmp, _, tmp_hdr = utils.load_nii(dwi_files[0])
    tmp_vd=tmp_hdr.get_zooms()

    if num_dwi == 1:
        fig, ax = plt.subplots(nrows=4, ncols=num_dwi+1, gridspec_kw={ 'width_ratios': [1, 1], 'height_ratios': [tmp.shape[2]/tmp_vd[1], tmp.shape[2]/tmp_vd[1], tmp.shape[1]/tmp_vd[2], 5/tmp_vd[1]]})
    else:
        fig, ax = plt.subplots(nrows=4, ncols=num_dwi+1, gridspec_kw={ 'width_ratios': [1, 1, 1], 'height_ratios': [tmp.shape[2]/tmp_vd[1], tmp.shape[2]/tmp_vd[1], tmp.shape[1]/tmp_vd[2], 5/tmp_vd[1]]})

    for i in range(num_dwi):

        dwi_file = dwi_files[i]
        bvals_file = bvals_files[i]
        bvecs_file = bvecs_files[i]

        bvals, _, _ = utils.shell_bvals(dwi_file, bvecs_file, bvals_file, B0thr)

        b0_file, _, _ = utils.dwi_extract_iDIO(dwi_file, bvals, temp_dir, target_bval=0, first_only=True)
        b0_img, b0_aff, _ = utils.load_nii(b0_file)

        b0_slices, b0_vox_dim, b0_min, b0_max = utils.slice_nii(b0_file, min_intensity=0, max_percentile=SHARED_VARS.VIS_PERCENTILE_MAX)

        dwi_prefixes.append(utils.get_prefix(dwi_file))
        dwi_pe_strs.append(utils.pescheme2axis(pe_axis[i], pe_dirs[i], b0_aff))

        for j in range(0,3):
            s, vox_ratio=utils.plot_slice_iDIO(slices=b0_slices, img_dim=j, offset_index=0, vox_dim=b0_vox_dim)
            ax[j, i].imshow(s, cmap='gray', vmin=b0_min, vmax=b0_max, aspect=vox_ratio, alpha=1)
            sc = utils.plot_slice_contour_iDIO(slices=eddy_mask_slices,img_dim=j, offset_index=0)
            for slice_contour in enumerate(sc):
                ax[j, i].plot(slice_contour[1][:,1], slice_contour[1][:,0], linewidth=0.8, color='r')
            #different label
            if j == 0:
                # ax[j, i].set_title('{}) {} ({})'.format(i+1, dwi_prefixes[i], dwi_pe_strs[i]), fontsize=SHARED_VARS.LABEL_FONTSIZE)
                ax[j, i].set_title('{}) {}'.format(i+1, dwi_prefixes[i]), fontsize=SHARED_VARS.LABEL_FONTSIZE)
                if i == 0:
                    ax[j, i].set_ylabel('Sagittal', fontsize=SHARED_VARS.LABEL_FONTSIZE)
            elif j == 1:
                if i == 0:
                    ax[j, i].set_ylabel('Coronal', fontsize=SHARED_VARS.LABEL_FONTSIZE)
            elif j==2:
                if i == 0:
                    ax[j, i].set_ylabel('Axial', fontsize=SHARED_VARS.LABEL_FONTSIZE)
            # set tick off
            ax[j, i].set_xticks([])
            ax[j, i].set_yticks([])


    b0_preproc_file, _, _ = utils.dwi_extract_iDIO(dwi_preproc_file, bvals_preproc_shelled, temp_dir, target_bval=0, first_only=True)
    b0_preproc_slices, b0_preproc_vox_dim, b0_preproc_min, b0_preproc_max = utils.slice_nii(b0_preproc_file, min_intensity=0, max_percentile=SHARED_VARS.VIS_PERCENTILE_MAX)

    mask_slices, _, _, _ = utils.slice_nii(mask_file)
    stats_mask_slices, _, _, _ = utils.slice_nii(stats_mask_file)

    for j in range(0,3):
        s, vox_ratio = utils.plot_slice_iDIO(slices=b0_preproc_slices, img_dim=j, offset_index=0, vox_dim=b0_preproc_vox_dim)
        ax[j, num_dwi].imshow(s, cmap='gray', vmin=b0_preproc_min, vmax=b0_preproc_max, aspect=vox_ratio, alpha=1)
        sc = utils.plot_slice_contour_iDIO(slices=mask_slices, img_dim=j, offset_index=0)
        for slice_contour in enumerate(sc):
            ax[j, num_dwi].plot(slice_contour[1][:,1], slice_contour[1][:,0], linewidth=0.8, color='c')
        sc = utils.plot_slice_contour_iDIO(slices=stats_mask_slices, img_dim=j, offset_index=0)
        for slice_contour in enumerate(sc):
            ax[j, num_dwi].plot(slice_contour[1][:,1], slice_contour[1][:,0], linewidth=0.8, color='m')
        ax[j,num_dwi].axis('off')
        if j == 0:
            ax[j, num_dwi].set_title('Preprocessed', fontsize=SHARED_VARS.LABEL_FONTSIZE)
        
    ax[3,num_dwi-1].plot([], linewidth=2, color='r', label='Eddy Mask')
    ax[3,num_dwi-1].plot([], linewidth=2, color='c', label='Preprocessed Mask\n({:.2f}% Improbable Voxels)'.format(percent_improbable))
    ax[3,num_dwi-1].plot([], linewidth=2, color='m', label='Brain Parachymal Volumes')
    handles, labels = ax[3,num_dwi-1].get_legend_handles_labels()
    fig.legend(loc='lower center', ncol=3, fontsize='small', frameon=False)
    for j in range(0,num_dwi+1):
        ax[3,j].axis('off')

    plt.tight_layout()
    plt.subplots_adjust(top=0.9)
    fig.set_size_inches(SHARED_VARS.PAGESIZE)
    plt.suptitle('Preprocessing Masks', fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')

    preproc_vis_file = os.path.join(vis_dir, 'preproc_masks.pdf')
    plt.savefig(preproc_vis_file, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    # utils.remove_dir(temp_dir)

    return preproc_vis_file

def vis_gradcheck(bvals_files, bvecs_files, bvals_preproc_file, bvecs_preproc_file, vis_dir):

    temp_dir = utils.make_dir(vis_dir, 'TMP')

    # Load and prepare gradients
    bvals = utils.load_txt(utils.bvals_merge(bvals_files, 'raw_merged', temp_dir), txt_type='bvals')
    bvecs = utils.load_txt(utils.bvecs_merge(bvecs_files, 'raw_merged', temp_dir), txt_type='bvecs')
    bvals_preproc = utils.load_txt(bvals_preproc_file, txt_type='bvals')
    bvecs_preproc = utils.load_txt(bvecs_preproc_file, txt_type='bvecs')

    scaled_bvecs = np.array([np.multiply(bvals, bvecs[0, :]), np.multiply(bvals, bvecs[1, :]), np.multiply(bvals, bvecs[2, :])])
    scaled_bvecs_preproc = np.array([np.multiply(bvals_preproc, bvecs_preproc[0, :]), np.multiply(bvals_preproc, bvecs_preproc[1, :]), np.multiply(bvals_preproc, bvecs_preproc[2, :])])

    # Visualize

    fig = plt.figure(0, figsize=SHARED_VARS.PAGESIZE)

    ax1 = plt.subplot2grid((3, 3), (0, 0), projection='3d')
    ax2 = plt.subplot2grid((3, 3), (1, 0), projection='3d')
    ax3 = plt.subplot2grid((3, 3), (2, 0), projection='3d')
    ax4 = plt.subplot2grid((3, 3), (0, 1), colspan=2, rowspan=3, projection='3d')

    ax4.scatter(scaled_bvecs[0, :], scaled_bvecs[1, :], scaled_bvecs[2, :], c='r', marker='o', s=60, label='Original', alpha=1)
    ax4.scatter(scaled_bvecs_preproc[0, :], scaled_bvecs_preproc[1, :], scaled_bvecs_preproc[2, :], c='b', marker='x', s=60, label='Eddy Preprocessed', alpha=0.7)
    plt.legend(fontsize=SHARED_VARS.LABEL_FONTSIZE)
    ax4.set_box_aspect([1,1,1]) # Make sure axes have equal aspect ratios
    ax_radius = 1.1*np.amax(bvals)
    ax4.set_xlim3d((-ax_radius, ax_radius))
    ax4.set_ylim3d((-ax_radius, ax_radius))
    ax4.set_zlim3d((-ax_radius, ax_radius))
    ax4.set_xlabel('x')
    ax4.set_ylabel('y')
    ax4.set_zlabel('z')

    # x-view (alpha depends on the view)
    ax1.scatter(scaled_bvecs_preproc[0, :], scaled_bvecs_preproc[1, :], scaled_bvecs_preproc[2, :], c='b', marker='x', s=5, label='Eddy Preprocessed', alpha=1)
    ax1.scatter(scaled_bvecs[0, :], scaled_bvecs[1, :], scaled_bvecs[2, :], c='r', marker='o', s=5, label='Original', alpha=0.5)
    ax1.set_xlim3d((-ax_radius, ax_radius))
    ax1.set_ylim3d((-ax_radius, ax_radius))
    ax1.set_zlim3d((-ax_radius, ax_radius))
    ax1.set_title('x-view', y=0.9)
    ax1.view_init(elev=0, azim=0)  
    ax1.set_ylabel('y', labelpad=-15)
    ax1.set_zlabel('z', labelpad=-15)
    ax1.set_xticks([])
    ax1.set_yticklabels([])
    ax1.set_zticklabels([])
    ax1.tick_params(labelsize=6)
    ax1.set_box_aspect([1,1,1])

    # y view
    ax2.scatter(scaled_bvecs[0, :], scaled_bvecs[1, :], scaled_bvecs[2, :], c='r', marker='o', s=5, label='Original', alpha=1)
    ax2.scatter(scaled_bvecs_preproc[0, :], scaled_bvecs_preproc[1, :], scaled_bvecs_preproc[2, :], c='b', marker='x', s=5, label='Eddy Preprocessed', alpha=0.5)
    ax2.set_xlim3d((-ax_radius, ax_radius))
    ax2.set_ylim3d((-ax_radius, ax_radius))
    ax2.set_zlim3d((-ax_radius, ax_radius))
    ax2.set_title('y-view', y=0.9)
    ax2.view_init(elev=0, azim=90)  
    ax2.set_xlabel('x', labelpad=-15)
    ax2.set_zlabel('z', labelpad=-15)
    ax2.set_xticklabels([])
    ax2.set_yticks([])
    ax2.set_zticklabels([])
    ax2.tick_params(labelsize=6)
    ax2.set_box_aspect([1,1,1])

    # z view
    ax3.scatter(scaled_bvecs[0, :], scaled_bvecs[1, :], scaled_bvecs[2, :], c='r', marker='o', s=5, label='Original', alpha=1)
    ax3.scatter(scaled_bvecs_preproc[0, :], scaled_bvecs_preproc[1, :], scaled_bvecs_preproc[2, :], c='b', marker='x', s=5, label='Eddy Preprocessed', alpha=0.5)
    ax3.set_xlim3d((-ax_radius, ax_radius))
    ax3.set_ylim3d((-ax_radius, ax_radius))
    ax3.set_zlim3d((-ax_radius, ax_radius))
    ax3.set_title('z-view', y=0.9)
    ax3.view_init(elev=90, azim=90)  
    ax3.set_xlabel('x', labelpad=-15)
    ax3.set_ylabel('y', labelpad=-15)
    ax3.set_xticklabels([])
    ax3.set_yticklabels([])
    ax3.set_zticks([])
    ax3.tick_params(labelsize=6)
    ax3.set_box_aspect([1,1,1])


    plt.tight_layout()

    plt.subplots_adjust(top=0.9)
    plt.suptitle('Gradient Check', fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')
    gradcheck_vis_file = os.path.join(vis_dir, 'gradcheck.pdf')
    plt.savefig(gradcheck_vis_file, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    # utils.remove_dir(temp_dir)

    return gradcheck_vis_file

def vis_dwi(dwi_file, bvals_shelled, cnr_mask, cnr_dict, vis_dir):

    temp_dir = utils.make_dir(vis_dir, 'TMP')

    dwi_vis_files = []
    bvals = np.sort(np.unique(bvals_shelled))
    stats_out_list = []

    for i in range(len(bvals)):

        bX = bvals[i]
        bXs_file, num_bXs, _ = utils.dwi_extract_iDIO(dwi_file, bvals_shelled, temp_dir, target_bval=bX, first_only=False)
        bXs_avg_file = utils.dwi_avg(bXs_file, temp_dir)
        bXs_avg_slices, bXs_avg_vox_dim, bXs_avg_min, bXs_avg_max = utils.slice_nii(bXs_avg_file, offsets=[-10, -5, 0, 5, 10], min_intensity=0, max_percentile=SHARED_VARS.VIS_PERCENTILE_MAX)
        
        cnr = '{:.3f}'.format(cnr_dict[bX])
        cnr_label = 'SNR' if bX == 0 else 'CNR'

        if bX != 0:
            bXs_vis_file = vis_vol(bXs_avg_slices, bXs_avg_vox_dim, bXs_avg_min, bXs_avg_max, vis_dir, name='Preprocessed_b_=_{},_{}_scan_average,_{}_=_{}'.format(bX, num_bXs, cnr_label, cnr), colorbar=False)
            dwi_vis_files.append(bXs_vis_file)

            stats_out_list.append('b{}_median_{},{}'.format(bX, 'cnr', cnr_dict[bX]))

        else:
            if num_bXs == 1:
                stats_out_list.append('b{}_median_{},{}'.format(int(bX), 'snr' , 'only one b0 image were acquired'))
            else:
                std_cmd = 'fslmaths {} -Tstd {}'.format(bXs_file, temp_dir + '/b0std.nii.gz')
                utils.run_cmd(std_cmd)
                snr_cmd = 'fslmaths {} -div {} {}'.format(bXs_avg_file, temp_dir + '/b0std.nii.gz', temp_dir + '/SNR.nii.gz')
                utils.run_cmd(snr_cmd)
                snr_img, _, _ = utils.load_nii(temp_dir + '/SNR.nii.gz', ndim=3)
                mask_img, _, _ = utils.load_nii(cnr_mask, dtype='bool', ndim=3)
                snr = np.nanmedian(snr_img[mask_img])
                # plot
                bXs_vis_file = vis_vol(bXs_avg_slices, bXs_avg_vox_dim, bXs_avg_min, bXs_avg_max, vis_dir, name='Preprocessed_b_=_{},_{}_scan_average,_{}_=_{:.3f}'.format(int(bX), num_bXs, cnr_label, snr), colorbar=False)
                dwi_vis_files.append(bXs_vis_file)

                stats_out_list.append('b{}_median_{},{}'.format(bX, 'snr' , snr))


    # utils.remove_dir(temp_dir)
    return dwi_vis_files, stats_out_list

def vis_stats(dwi_file, bvals_file, motion_dict, EC_dict, eddy_dir, vis_dir):

    # Load data
    eddy_outlier_map_file = glob.glob(eddy_dir + '/*.eddy_outlier_map')[0]
    eddy_num_std_file = glob.glob(eddy_dir + '/*.eddy_outlier_n_stdev_map')[0]        

    bvals = np.array(bvals_file)
    # Configure figure
    fig = plt.figure(0, figsize=SHARED_VARS.PAGESIZE)

    # Visualize rotations
    rotations = motion_dict['rotations']
    
    ax = plt.subplot(6, 3, 1)
    ax0 = ax.get_position()
    box_width = ax.get_position().x1-ax.get_position().x0+0.05
    # box_height = ax.get_position().y1-ax.get_position().y0
    box_height = 0.11
    ax.axis('off')

    ax = plt.subplot(6, 3, 16)
    ax1 = ax.get_position()
    ax.axis('off')

    ax = fig.add_axes([ax0.x0, ax0.y0, box_width, box_height])    
    plt.plot(range(0, rotations.shape[0]), rotations[:, 0], color='tab:red', label='Avg. x ({:.2f})'.format(motion_dict['eddy_avg_rotations'][0]), alpha=0.9)
    plt.plot(range(0, rotations.shape[0]), rotations[:, 1], color='tab:green', label='Avg. y ({:.2f})'.format(motion_dict['eddy_avg_rotations'][1]), alpha=0.9)
    plt.plot(range(0, rotations.shape[0]), rotations[:, 2], color='tab:blue', label='Avg. z ({:.2f})'.format(motion_dict['eddy_avg_rotations'][2]), alpha=0.9)
    plt.xlim((-1, rotations.shape[0]+1))
    ax.spines['bottom'].set_visible(False)
    ax.tick_params(labelbottom=False)
    plt.ylabel('Rotation\n(deg)', fontsize=3*SHARED_VARS.LABEL_FONTSIZE/4)
    plt.grid()
    plt.legend(fontsize=2*SHARED_VARS.LABEL_FONTSIZE/3, loc='upper left', framealpha=0.6, handlelength=1)
    plt.title('Subject Motion', fontsize=SHARED_VARS.TITLE_FONTSIZE)
    ax.get_yaxis().set_label_coords(-0.18,0.5)

    # Visualize translations

    translations = motion_dict['translations']

    # ax = plt.subplot(6, 3, 4)
    ax = fig.add_axes([ax0.x0, ax0.y0-box_height*1, box_width, box_height])
    plt.plot(range(0, translations.shape[0]), translations[:, 0], color='tab:red', label='Avg. x ({:.2f})'.format(motion_dict['eddy_avg_translations'][0]), alpha=0.9)
    plt.plot(range(0, translations.shape[0]), translations[:, 1], color='tab:green', label='Avg. y ({:.2f})'.format(motion_dict['eddy_avg_translations'][1]), alpha=0.9)
    plt.plot(range(0, translations.shape[0]), translations[:, 2], color='tab:blue', label='Avg. z ({:.2f})'.format(motion_dict['eddy_avg_translations'][2]), alpha=0.9)
    plt.xlim((-1, translations.shape[0]+1))
    ax.spines['bottom'].set_visible(False)
    ax.tick_params(labelbottom=False)
    plt.ylabel('Translation\n(mm)', fontsize=3*SHARED_VARS.LABEL_FONTSIZE/4)
    plt.grid()
    plt.legend(fontsize=2*SHARED_VARS.LABEL_FONTSIZE/3, loc='upper left', framealpha=0.6, handlelength=1)
    ax.get_yaxis().set_label_coords(-0.18,0.5)

    # Visualize RMS Displacement

    abs_displacement = motion_dict['abs_displacement']
    rel_displacement = motion_dict['rel_displacement']

    # ax = plt.subplot(6, 3, 7)
    ax = fig.add_axes([ax0.x0, ax0.y0-box_height*2, box_width, box_height])
    plt.plot(range(0, abs_displacement.shape[0]), abs_displacement, color='tab:red', label='Avg. Abs. ({:.2f})'.format(motion_dict['eddy_avg_abs_displacement'][0]), alpha=0.9)
    plt.plot(range(0, rel_displacement.shape[0]), rel_displacement, color='tab:blue', label='Avg. Rel. ({:.2f})'.format(motion_dict['eddy_avg_rel_displacement'][0]), alpha=0.9)
    plt.xlim((-1, abs_displacement.shape[0]+1))
    # ax.tick_params(labelbottom=False)
    plt.ylabel('Displacement\n(mm)', fontsize=3*SHARED_VARS.LABEL_FONTSIZE/4)
    plt.grid()
    plt.legend(fontsize=2*SHARED_VARS.LABEL_FONTSIZE/3, loc='upper left', framealpha=0.6, handlelength=1)
    ax.set_xlabel('Diffusion Volume', fontsize=SHARED_VARS.LABEL_FONTSIZE)
    ax.get_yaxis().set_label_coords(-0.18,0.5)

    # ax.axis["left"].major_ticklabels.set_ha("left")

    # show EC results 
    linear_x = EC_dict['eddy_linear_x']
    linear_y = EC_dict['eddy_linear_y']
    linear_z = EC_dict['eddy_linear_z']

    # ax = plt.subplot(6, 3, 10)
    ax = fig.add_axes([ax0.x0, ax1.y0+box_height*2, box_width, box_height])
    plt.plot(range(0, linear_x.shape[0]), linear_x[:], color='tab:red', label='SD x. ({:.2f})'.format(np.std(linear_x)))
    plt.xlim((-1, linear_x.shape[0]+1))
    ax.spines['bottom'].set_visible(False)
    ax.tick_params(labelbottom=False)
    plt.ylabel('x-axis\n(Hz/mm)', fontsize=3*SHARED_VARS.LABEL_FONTSIZE/4)
    plt.grid()
    plt.legend(fontsize=2*SHARED_VARS.LABEL_FONTSIZE/3, loc='upper left', framealpha=0.6, handlelength=1)
    plt.title('EC-induced linear terms', fontsize=SHARED_VARS.TITLE_FONTSIZE)
    ax.get_yaxis().set_label_coords(-0.18,0.5)

    # ax = plt.subplot(6, 3, 13)
    ax = fig.add_axes([ax0.x0, ax1.y0+box_height*1, box_width, box_height])
    plt.plot(range(0, linear_y.shape[0]), linear_y[:], color='tab:green', label='SD y. ({:.2f})'.format(np.std(linear_y)))
    plt.xlim((-1, linear_y.shape[0]+1))
    ax.spines['bottom'].set_visible(False)
    ax.tick_params(labelbottom=False)
    plt.ylabel('y-axis\n(Hz/mm)', fontsize=3*SHARED_VARS.LABEL_FONTSIZE/4)
    plt.grid()
    plt.legend(fontsize=2*SHARED_VARS.LABEL_FONTSIZE/3, loc='upper left', framealpha=0.6, handlelength=1)
    ax.get_yaxis().set_label_coords(-0.18,0.5)

    # ax = plt.subplot(6, 3, 16)
    ax = fig.add_axes([ax0.x0, ax1.y0+box_height*0, box_width, box_height])
    plt.plot(range(0, linear_z.shape[0]), linear_z[:], color='tab:blue', label='SD z. ({:.2f})'.format(np.std(linear_z)))
    plt.xlim((-1, linear_z.shape[0]+1))
    ax.get_yaxis().set_label_coords(-0.18,0.5)
    plt.ylabel('z-axis\n(Hz/mm)', fontsize=3*SHARED_VARS.LABEL_FONTSIZE/4)
    plt.grid()
    plt.legend(fontsize=2*SHARED_VARS.LABEL_FONTSIZE/3, loc='upper left', framealpha=0.6, handlelength=1)
    ax.set_xlabel('Diffusion Volume', fontsize=SHARED_VARS.LABEL_FONTSIZE)
    
    # Visualize outlier map
    Outlier_warning=[]
    raw_outlier_map = _get_outlier_map(eddy_outlier_map_file)
    outlier_map = np.transpose(raw_outlier_map)
    outlier_percentage = len(np.where(raw_outlier_map[bvals!=0,:]==1)[0])/outlier_map.shape[0]/len(np.where(bvals!=0)[0])

    for vol in range(outlier_map.shape[1]):
        if sum(outlier_map)[vol]/outlier_map.shape[0] > 0.05:
            Outlier_warning.append('    {} out of {} slices shown as outliers in volume {}'.format(sum(outlier_map)[vol], outlier_map.shape[0], vol))

    ax = plt.subplot(4, 2, 2)
    ax.matshow(outlier_map, aspect='auto', origin='lower')#, cmap = )
    ax.set_title('Eddy Outlier Slices ({:.2f}%)'.format(outlier_percentage*100), fontsize=SHARED_VARS.TITLE_FONTSIZE)
    ax.xaxis.set_ticks_position('bottom')
    # ax.set_xticks(range(0, outlier_map.shape[1],10))
    ax.set_xlabel('Diffusion Volume', fontsize=SHARED_VARS.LABEL_FONTSIZE)
    ax.set_ylabel('Slice', fontsize=SHARED_VARS.LABEL_FONTSIZE)
    plt.xlim(-0.5, outlier_map.shape[1]-0.5)
    plt.ylim(-0.5, outlier_map.shape[0]-0.5)
    for xnew in range(0, outlier_map.shape[1],10):
        ax.axvline(xnew+0.5, color='gray', linewidth=0.5)
        ax.axvline(xnew-0.5, color='gray', linewidth=0.5)

    # Visualize Eddy outlier number of standard deviation
    num_std_matrix = _get_eddy_num_std_map(eddy_num_std_file)
    num_std_matrix = np.transpose(num_std_matrix)
    matrix_slices = np.nanmedian(num_std_matrix, axis=1)
    matrix_vols = np.nanmedian(num_std_matrix, axis=0)

    ax = plt.subplot(12, 2, 12)
    ax.plot(list(range(0, len(matrix_vols))), matrix_vols)
    plt.xlim(-0.5, len(matrix_vols)-0.5)
    ax.tick_params(axis='y', labelsize=SHARED_VARS.LABEL_FONTSIZE*0.8)
    ax.grid()
    ax.set_title('No. of std. off Mean Difference', fontsize=SHARED_VARS.TITLE_FONTSIZE)
    ax.spines['bottom'].set_visible(False)

    ax = plt.subplot(2, 16, 24)
    ax.plot(matrix_slices, list(range(0, len(matrix_slices))))
    ax.invert_xaxis()
    plt.xticks(rotation=60)
    plt.ylim(-0.5, len(matrix_slices)-0.5)
    ax.tick_params(axis='x', labelsize=SHARED_VARS.LABEL_FONTSIZE*0.8)
    ax.set_ylabel('Slice', fontsize=SHARED_VARS.LABEL_FONTSIZE) 
    ax.grid()
    ax.spines['right'].set_visible(False)

    ax = plt.subplot(2, 2, 4)
    im = ax.imshow(num_std_matrix, aspect='auto', origin='lower', interpolation='nearest', vmin=-4, vmax=4, cmap='RdBu_r')
    ax.set_xlabel('Diffusion Volume', fontsize=SHARED_VARS.LABEL_FONTSIZE)
    ax.xaxis.set_ticks_position('bottom')
    ax.yaxis.set_ticks_position('right')
    ax.yaxis.set_label_position('right')
    plt.xlim(-0.5, num_std_matrix.shape[1]-0.5)
    plt.ylim(-0.5, num_std_matrix.shape[0]-0.5)
    for xnew in range(0, outlier_map.shape[1], 10):
        ax.axvline(xnew+0.5, color='gray', linewidth=0.5)
        ax.axvline(xnew-0.5, color='gray', linewidth=0.5)

    # plt.subplots_adjust(right=0.85)
    # create colorbar axes as main plot
    plt.subplots_adjust(hspace=0, wspace=0)

    cax = fig.add_axes([ax.get_position().x1+0.03,ax.get_position().y0, 0.012, ax.get_position().height]) 
    plt.colorbar(im, cax=cax)
    
    plt.suptitle('Eddy and Motion Correction', fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')
    # Finish Up Figure

    stats_vis_file = os.path.join(vis_dir, 'stats.pdf')
    plt.savefig(stats_vis_file, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    return stats_vis_file, outlier_percentage, Outlier_warning

def vis_drift(png_path, vis_dir):
    driftb0 = os.path.join(png_path, 'Drifting_Correction_B0only.png')
    driftall = os.path.join(png_path, 'Drifting_Correction_allData.png')

    plt.figure(0, figsize=SHARED_VARS.PAGESIZE)
    image1 = mpimg.imread(driftb0)
    ax = plt.subplot(1,2,1)
    plt.imshow(image1)
    plt.axis('off')
    ax.set_title('b0 only', fontsize=SHARED_VARS.LABEL_FONTSIZE)
    plt.tight_layout()

    image2 = mpimg.imread(driftall)
    ax = plt.subplot(1,2,2)
    fig = plt.imshow(image2)
    plt.axis('off')
    ax.set_title('All diffusion volumes', fontsize=SHARED_VARS.LABEL_FONTSIZE)
    plt.tight_layout()

    plt.subplots_adjust(top=0.9)
    plt.suptitle('Drift Correction', fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')

    drift_vis_file = os.path.join(vis_dir, 'drift.pdf')
    plt.subplots_adjust(hspace=0, wspace=0.05)
    plt.savefig(drift_vis_file, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    return drift_vis_file

def vis_glyphs(fa_file, odf_file, cc_center_voxel, vis_dir, glyph_type='ODF'):

    temp_dir = utils.make_dir(vis_dir, 'TMP')

    # Prepare mrview command: Location to visualize

    cc_center_voxel_str = ','.join([str(np.round(loc)) for loc in cc_center_voxel])

    # Prepare mrview command: Planes to visualize + correspondence with file names

    planes = {
        0: 'sagittal',
        1: 'coronal',
        2: 'axial'
    }

    # Prepare mrview command: Glyphs, either CSD
    if glyph_type == 'ODF':
        print('VISUALIZING fODF map')
        fa_file = fa_file
        glyph_file = odf_file
        glyph_load_str = '-odf.load_sh'
        glyph_title_str = 'Fiber ODF'
    
    # Generate mrview commands and plot glyphs
        for i in planes:
            vis_cmd = 'mrview -load {} {} {} -mode 1 -plane {} -fov 160 -voxel {} -focus 0 -size 1200,1200 -colourbar 0 -config MRViewOdfScale 4 -config MRViewShowVoxelInformation false -config MRViewShowComments false -config MRViewShowOrientationLabel false -noannotations -capture.folder {} -capture.prefix {} -capture.grab -exit -nthreads {}'.format(
                fa_file[0], glyph_load_str, glyph_file[0], i, cc_center_voxel_str, temp_dir, planes[i], SHARED_VARS.NUM_THREADS-1
            )
            utils.run_cmd(vis_cmd) # will save as '<planes[i]>0000.png'
            vis_zoom_cmd = 'mrview -load {} {} {} -mode 1 -plane {} -fov 80 -voxel {} -focus 0 -size 1200,1200 -colourbar 0 -config MRViewOdfScale 4 -config MRViewShowVoxelInformation false -config MRViewShowComments false -config MRViewShowOrientationLabel false -noannotations -capture.folder {} -capture.prefix {} -capture.grab -exit -nthreads {}'.format(
                fa_file[0], glyph_load_str, glyph_file[0], i, cc_center_voxel_str, temp_dir, '{}_zoom'.format(planes[i]), SHARED_VARS.NUM_THREADS-1 # will save as 'planes[i]_zoom0000.png'
            )
            utils.run_cmd(vis_zoom_cmd)
        glyph_vis_file = os.path.join(vis_dir, 'glyphs_ODF.pdf')

    plt.figure(0, figsize=SHARED_VARS.PAGESIZE)

    plt.subplot(2, 3, 1)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'sagittal0000.png')))
    plt.xticks([], [])
    plt.yticks([], [])
    plt.ylabel('160 mm FOV', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.subplot(2, 3, 4)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'sagittal_zoom0000.png')))
    plt.xticks([], [])
    plt.yticks([], [])
    plt.ylabel('80 mm FOV', fontsize=SHARED_VARS.LABEL_FONTSIZE)
    plt.xlabel('Sagittal', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.subplot(2, 3, 2)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'coronal0000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.subplot(2, 3, 5)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'coronal_zoom0000.png')))
    plt.xticks([], [])
    plt.yticks([], [])
    plt.xlabel('Coronal', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.subplot(2, 3, 3)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'axial0000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.subplot(2, 3, 6)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'axial_zoom0000.png')))
    plt.xticks([], [])
    plt.yticks([], [])
    plt.xlabel('Axial', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.tight_layout()

    plt.suptitle('{}'.format(glyph_title_str), fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')
    plt.savefig(glyph_vis_file, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    # utils.remove_dir(temp_dir)

    return glyph_vis_file

def vis_slice(input_file, vis_dir, map_type):

    temp_dir = utils.make_dir(vis_dir, 'TMP')
    temp_dir = utils.make_dir(temp_dir, 'VIS')

    #Prepare mrview command
    print('VISUALIZING ' + map_type +' map')

    # Extract voxel dimensions/center in radiological view
    nii = nib.load(input_file)
    img = nii.get_fdata()
    axis_order = utils.radiological_order(nii.affine)
    i0 = int(round(img.shape[axis_order[0]] / 2, 1))
    i1 = int(round(img.shape[axis_order[1]] / 2, 1))
    i2 = int(round((img.shape[axis_order[2]] - 60) / 2, 1))
    i2_2 = i2 + 15
    i2_3 = i2_2 + 15
    i2_4 = i2_3 + 15

    if map_type == 'DEC':
        temp_dir = utils.make_dir(temp_dir, 'DEC')
        vis_file = os.path.join(vis_dir, 'dec.pdf')
        imageinfo='-intensity_range 0,0.6'
    elif map_type == 'SSE':
        temp_dir = utils.make_dir(temp_dir, 'SSE')
        vis_file = os.path.join(vis_dir, 'sse.pdf')
        P97 = utils.run_cmd_output('fslstats {} -P 97'.format(input_file))
        imageinfo='-intensity_range 0,{:.2f} -colourmap 2'.format(float(P97))


    #Generate mrview command and plot light box
    vis_cmd = 'mrview -load {} -mode 4 -plane 2 -voxel {},{},{} {} -size 1200,1200 -noannotations -colourbar 0 -focus 0 -voxelinfo 0 -config MRViewShowVoxelInformation false -config MRViewShowComments false -capture.folder {} -capture.prefix {} -capture.grab  -exit  -nthreads {}'.format(input_file, i0, i1, i2, imageinfo, temp_dir, 'S1', SHARED_VARS.NUM_THREADS-1)
    utils.run_cmd(vis_cmd)

    vis_cmd = 'mrview -load {} -mode 4 -plane 2 -voxel {},{},{} {} -size 1200,1200 -noannotations -colourbar 0 -focus 0 -voxelinfo 0 -config MRViewShowVoxelInformation false -config MRViewShowComments false -config MRViewShowOrientationLabel false -capture.folder {} -capture.prefix {} -capture.grab -exit -nthreads {}'.format(input_file, i0, i1, i2_2, imageinfo, temp_dir, 'S2', SHARED_VARS.NUM_THREADS-1)
    utils.run_cmd(vis_cmd)

    vis_cmd = 'mrview -load {} -mode 4 -plane 2 -voxel {},{},{} {} -size 1200,1200 -noannotations -colourbar 0 -focus 0 -voxelinfo 0 -config MRViewShowVoxelInformation false -config MRViewShowComments false -config MRViewShowOrientationLabel false -capture.folder {} -capture.prefix {} -capture.grab -exit -voxelinfo 0 -nthreads {}'.format(input_file, i0, i1, i2_3, imageinfo, temp_dir, 'S3', SHARED_VARS.NUM_THREADS-1)
    utils.run_cmd(vis_cmd)

    vis_cmd = 'mrview -load {} -mode 4 -plane 2 -voxel {},{},{} {} -size 1200,1200 -noannotations -colourbar 0 -focus 0 -voxelinfo 0 -config MRViewShowVoxelInformation false -config MRViewShowComments false -config MRViewShowOrientationLabel false -capture.folder {} -capture.prefix {} -capture.grab -exit -nthreads {}'.format(input_file, i0, i1, i2_4, imageinfo, temp_dir, 'S4', SHARED_VARS.NUM_THREADS-1)
    utils.run_cmd(vis_cmd)

    # Merge to PDF
    plt.figure(0, figsize=SHARED_VARS.PAGESIZE)
    
    plt.subplot(2,2,1)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'S10000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.subplot(2,2,3)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'S20000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.subplot(2,2,2)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'S30000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.subplot(2,2,4)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'S40000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.tight_layout()

    plt.subplots_adjust(top=0.9)
    plt.subplots_adjust(hspace=0, wspace=0.025)
    
    if map_type == 'DEC': 
        plt.suptitle('DEC map \n (Intesity scaling: [0 0.6])', fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')
    elif map_type == 'SSE':
        plt.suptitle('SSE map \n (Intesity scaling: [0 {:.2f}])'.format(float(P97)), fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')
    
    plt.savefig(vis_file, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    # utils.remove_dir(temp_dir)

    return vis_file

def vis_overlap_slice(input_file, mask_file, vis_dir, percent_improbable):

    temp_dir = utils.make_dir(vis_dir, 'TMP')
    temp_dir = utils.make_dir(temp_dir, 'OVERLAP')

    # Extract voxel dimensions/center in radiological view
    nii = nib.load(input_file)
    img = nii.get_fdata()
    axis_order = utils.radiological_order(nii.affine)
    i0 = int(round(img.shape[axis_order[0]] / 2, 1))
    i1 = int(round(img.shape[axis_order[1]] / 2, 1))
    i2 = int(round((img.shape[axis_order[2]] - 60) / 2, 1))
    i2_2 = i2 + 15
    i2_3 = i2_2 + 15
    i2_4 = i2_3 + 15

    vis_file = os.path.join(vis_dir, 'Improbable_voxels.pdf')
    
    imageinfo='-intensity_range 0,1 -overlay.threshold_min 0.01'


    #Generate mrview command and plot light box
    vis_cmd = 'mrview -load {} -mode 4 -plane 2 -voxel {},{},{} {} -size 1200,1200 -config MRViewShowVoxelInformation false -config MRViewShowComments false -nthreads {} -overlay.load {} -overlay.colour 1,0,0 -overlay.interpolation 0 -noannotations -colourbar 0 -focus 0 -voxelinfo 0 -capture.folder {} -capture.prefix {} -capture.grab -exit'.format(input_file, i0, i1, i2, imageinfo, SHARED_VARS.NUM_THREADS-1, mask_file, temp_dir, 'S1')
    utils.run_cmd(vis_cmd)

    vis_cmd = 'mrview -load {} -mode 4 -plane 2 -voxel {},{},{} {} -size 1200,1200 -config MRViewShowVoxelInformation false -config MRViewShowComments false -config MRViewShowOrientationLabel false -nthreads {} -overlay.load {} -overlay.colour 1,0,0 -overlay.interpolation 0 -noannotations -colourbar 0 -focus 0 -voxelinfo 0 -capture.folder {} -capture.prefix {} -capture.grab -exit '.format(input_file, i0, i1, i2_2, imageinfo, SHARED_VARS.NUM_THREADS-1, mask_file, temp_dir, 'S2')
    utils.run_cmd(vis_cmd)

    vis_cmd = 'mrview -load {} -mode 4 -plane 2 -voxel {},{},{} {} -size 1200,1200 -config MRViewShowVoxelInformation false -config MRViewShowComments false -config MRViewShowOrientationLabel false -nthreads {} -overlay.load {} -overlay.colour 1,0,0 -overlay.interpolation 0 -noannotations -colourbar 0 -focus 0 -voxelinfo 0 -capture.folder {} -capture.prefix {} -capture.grab -exit' .format(input_file, i0, i1, i2_3, imageinfo, SHARED_VARS.NUM_THREADS-1, mask_file, temp_dir, 'S3')
    utils.run_cmd(vis_cmd)

    vis_cmd = 'mrview -load {} -mode 4 -plane 2 -voxel {},{},{} {} -size 1200,1200 -config MRViewShowVoxelInformation false -config MRViewShowComments false -config MRViewShowOrientationLabel false -nthreads {} -overlay.load {} -overlay.colour 1,0,0 -overlay.interpolation 0 -noannotations -colourbar 0 -focus 0 -voxelinfo 0 -capture.folder {} -capture.prefix {} -capture.grab -exit'.format(input_file, i0, i1, i2_4, imageinfo, SHARED_VARS.NUM_THREADS-1, mask_file, temp_dir, 'S4')
    utils.run_cmd(vis_cmd)

    # Merge to PDF
    plt.figure(0, figsize=SHARED_VARS.PAGESIZE)
    
    plt.subplot(2,2,1)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'S10000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.subplot(2,2,3)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'S20000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.subplot(2,2,2)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'S30000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.subplot(2,2,4)
    plt.imshow(plt.imread(os.path.join(temp_dir, 'S40000.png')))
    plt.xticks([], [])
    plt.yticks([], [])

    plt.tight_layout()

    plt.subplots_adjust(top=0.9)
    plt.subplots_adjust(hspace=0, wspace=0.025)
    
    plt.suptitle('Improbable Voxels ({:.2f}%)'.format(percent_improbable), fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')
    
    plt.savefig(vis_file, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    # utils.remove_dir(temp_dir)

    return vis_file

def vis_noise_comp(raw_file, res_file, denoise_file, bvals, vis_dir, shells=[]):

    temp_dir = utils.make_dir(vis_dir, 'TMP')

    bvals_unique = np.sort(np.unique(bvals))

    # extract b image
    noise_vis_file = []
    for i in range(len(bvals_unique)):
        b0_file, _, _ = utils.dwi_extract_iDIO(raw_file, bvals, temp_dir, target_bval=bvals_unique[i], first_only=True)
        b0_denoise_file, _, _ = utils.dwi_extract_iDIO(denoise_file, bvals, temp_dir, target_bval=bvals_unique[i], first_only=True)
        res_file_shell, _, _ = utils.dwi_extract_iDIO(res_file, bvals, temp_dir, target_bval=bvals_unique[i])
        # average shell res image
        mean_res_file = utils.dwi_avg(res_file_shell,temp_dir)

        # select plot slice
        b0_slices, b0_vox_dim, b0_min, b0_max = utils.slice_nii(b0_file, min_intensity=0, max_percentile=SHARED_VARS.VIS_PERCENTILE_MAX)
        res_field_slices, res_field_vox_dim, res_field_min, res_field_max = utils.slice_nii(mean_res_file)
        b0_denoise_slices, b0_denoise_vox_dim, b0_denoise_min, b0_denoise_max = utils.slice_nii(b0_denoise_file, min_intensity=0, max_percentile=SHARED_VARS.VIS_PERCENTILE_MAX)

        fig = plt.figure(0, figsize=SHARED_VARS.PAGESIZE)

        plt.subplot(3, 3, 1)
        utils.plot_slice(slices=b0_slices, img_dim=0, offset_index=0, vox_dim=b0_vox_dim, img_min=b0_min, img_max=b0_max)
        plt.colorbar()
        plt.title('Raw', fontsize=SHARED_VARS.LABEL_FONTSIZE)
        plt.ylabel('Sagittal', fontsize=SHARED_VARS.LABEL_FONTSIZE)

        plt.subplot(3, 3, 4)
        utils.plot_slice(slices=b0_slices, img_dim=1, offset_index=0, vox_dim=b0_vox_dim, img_min=b0_min, img_max=b0_max)
        plt.colorbar()
        plt.ylabel('Coronal', fontsize=SHARED_VARS.LABEL_FONTSIZE)

        plt.subplot(3, 3, 7)
        utils.plot_slice(slices=b0_slices, img_dim=2, offset_index=0, vox_dim=b0_vox_dim, img_min=b0_min, img_max=b0_max)
        plt.colorbar()
        plt.ylabel('Axial', fontsize=SHARED_VARS.LABEL_FONTSIZE)

        # plot residual with 10% maximum and minimum
        plt.subplot(3, 3, 2)
        utils.plot_slice(slices=res_field_slices, img_dim=0, offset_index=0, vox_dim=res_field_vox_dim, img_min=res_field_min*0.2, img_max=res_field_max*0.2, cmap='jet')
        plt.colorbar()
        plt.title('Mean residual', fontsize=SHARED_VARS.LABEL_FONTSIZE)

        plt.subplot(3, 3, 5)
        utils.plot_slice(slices=res_field_slices, img_dim=1, offset_index=0, vox_dim=res_field_vox_dim, img_min=res_field_min*0.2, img_max=res_field_max*0.2, cmap='jet')

        plt.colorbar()

        plt.subplot(3, 3, 8)
        utils.plot_slice(slices=res_field_slices, img_dim=2, offset_index=0, vox_dim=res_field_vox_dim, img_min=res_field_min*0.2, img_max=res_field_max*0.2, cmap='jet')
        plt.colorbar()

        # plot denoise map with same contrast with b0
        plt.subplot(3, 3, 3)
        utils.plot_slice(slices=b0_denoise_slices, img_dim=0, offset_index=0, vox_dim=b0_denoise_vox_dim, img_min=b0_min, img_max=b0_max)
        plt.colorbar()
        plt.title('Denoise', fontsize=SHARED_VARS.LABEL_FONTSIZE)

        plt.subplot(3, 3, 6)
        utils.plot_slice(slices=b0_denoise_slices, img_dim=1, offset_index=0, vox_dim=b0_denoise_vox_dim, img_min=b0_min, img_max=b0_max)
        plt.colorbar()

        plt.subplot(3, 3, 9)
        utils.plot_slice(slices=b0_denoise_slices, img_dim=2, offset_index=0, vox_dim=b0_denoise_vox_dim, img_min=b0_min, img_max=b0_max)
        plt.colorbar()

        for j in range(0,18):
            fig.get_axes()[j].set_anchor('C')

        plt.tight_layout()

        plt.subplots_adjust(top=0.9)
        plt.suptitle('Denoise ( b = {} )'.format(str(int(bvals_unique[i]))), fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')

        noise_vis_file.append(os.path.join(vis_dir, 'noise_{}.pdf'.format(str(int(bvals_unique[i])))))
        plt.savefig(noise_vis_file[i], dpi=SHARED_VARS.PDF_DPI)
        plt.close()

    # utils.remove_dir(temp_dir)

    return noise_vis_file

def vis_bias(raw_file, biasField, unbiased_file, bvals, vis_dir):

    temp_dir = utils.make_dir(vis_dir, 'TMP')

    b0_file, _, _ = utils.dwi_extract_iDIO(raw_file, bvals, temp_dir, target_bval=0, first_only=True)
    b0_unbiased_file, _, _ = utils.dwi_extract_iDIO(unbiased_file, bvals, temp_dir, target_bval=0, first_only=True)

    b0_slices, b0_vox_dim, b0_min, b0_max = utils.slice_nii(b0_file, min_intensity=0, max_percentile=SHARED_VARS.VIS_PERCENTILE_MAX)
    bias_field_slices, bias_field_vox_dim, bias_field_min, bias_field_max = utils.slice_nii(biasField)
    b0_unbiased_slices, b0_unbiased_vox_dim, b0_unbiased_min, b0_unbiased_max = utils.slice_nii(b0_unbiased_file, min_intensity=0, max_percentile=SHARED_VARS.VIS_PERCENTILE_MAX)

    fig = plt.figure(0, figsize=SHARED_VARS.PAGESIZE)

    plt.subplot(3, 3, 1)
    utils.plot_slice(slices=b0_slices, img_dim=0, offset_index=0, vox_dim=b0_vox_dim, img_min=b0_min, img_max=b0_max)
    plt.colorbar()
    plt.title('Biased', fontsize=SHARED_VARS.LABEL_FONTSIZE)
    plt.ylabel('Sagittal', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.subplot(3, 3, 4)
    utils.plot_slice(slices=b0_slices, img_dim=1, offset_index=0, vox_dim=b0_vox_dim, img_min=b0_min, img_max=b0_max)
    plt.colorbar()
    plt.ylabel('Coronal', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.subplot(3, 3, 7)
    utils.plot_slice(slices=b0_slices, img_dim=2, offset_index=0, vox_dim=b0_vox_dim, img_min=b0_min, img_max=b0_max)
    plt.colorbar()
    plt.ylabel('Axial', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.subplot(3, 3, 2)
    utils.plot_slice(slices=bias_field_slices, img_dim=0, offset_index=0, vox_dim=bias_field_vox_dim, img_min=bias_field_min, img_max=bias_field_max, cmap='jet')
    plt.colorbar()
    plt.title('Bias Field', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.subplot(3, 3, 5)
    utils.plot_slice(slices=bias_field_slices, img_dim=1, offset_index=0, vox_dim=bias_field_vox_dim, img_min=bias_field_min, img_max=bias_field_max, cmap='jet')
    plt.colorbar()

    plt.subplot(3, 3, 8)
    utils.plot_slice(slices=bias_field_slices, img_dim=2, offset_index=0, vox_dim=bias_field_vox_dim, img_min=bias_field_min, img_max=bias_field_max, cmap='jet')
    plt.colorbar()

    plt.subplot(3, 3, 3)
    utils.plot_slice(slices=b0_unbiased_slices, img_dim=0, offset_index=0, vox_dim=b0_unbiased_vox_dim, img_min=b0_min, img_max=b0_max)
    plt.colorbar()
    plt.title('Unbiased', fontsize=SHARED_VARS.LABEL_FONTSIZE)

    plt.subplot(3, 3, 6)
    utils.plot_slice(slices=b0_unbiased_slices, img_dim=1, offset_index=0, vox_dim=b0_unbiased_vox_dim, img_min=b0_min, img_max=b0_max)
    plt.colorbar()

    plt.subplot(3, 3, 9)
    utils.plot_slice(slices=b0_unbiased_slices, img_dim=2, offset_index=0, vox_dim=b0_unbiased_vox_dim, img_min=b0_min, img_max=b0_max)
    plt.colorbar()
    for j in range(0,18):
        fig.get_axes()[j].set_anchor('C')

    plt.tight_layout()

    plt.subplots_adjust(top=0.9)
    plt.suptitle('N4 Bias Field Correction', fontsize=SHARED_VARS.TITLE_FONTSIZE, fontweight='bold')

    bias_vis_file = os.path.join(vis_dir, 'bias.pdf')
    plt.savefig(bias_vis_file, dpi=SHARED_VARS.PDF_DPI)
    plt.close()

    # utils.remove_dir(temp_dir)

    return bias_vis_file

def vis_title(iDIO_Output, outlier_warning, vis_dir):
    title_str = str('iDIO v{} QC report\n'.format(SHARED_VARS.VERSION))
    c = 1
    warning_str =[]
    method_str = []
    Reference_str=[]

    # overall
    method_str.append(r"$\bf{\blacktriangleright\ The\ diffusion\ data\ were\ processed\ with\ iDIO\ toolbox:}$" + ' its functionalities come from MRtrix3 (https://www.mrtrix.org/), FSL (https://fsl.fmrib.ox.ac.uk/), ANTs (http://stnava.github.io/ANTs/), and PreQual (https://github.com/MASILab/PreQual)  software packages [{}, {}, {}, {}].'.format(c, c+1, c+2, c+3))
    Reference_str.append('[{}] Tournier, J. D.; Smith, R. E.; Raffelt, D., Tabbara, R., Dhollander, T., Pietsch, M., Christiaens, D., Jeurissen, B., Yeh, C.-H. & Connelly, A. MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. NeuroImage, 2019, 202:116137'.format(c))
    Reference_str.append('[{}] Jenkinson, M., Beckmann, C. F., Behrens, T. E., Woolrich, M.W., Smith. S.M., FSL. NeuroImage, 2012, 62:782-90'.format(c+1))
    Reference_str.append('[{}] Avants B. B., Tustison N. J., Song G. Advanced normalization tools (ANTS). Insight j, 2009, 2:1-35.'.format(c+2))
    Reference_str.append('[{}] Cai L. Y.; Yang Q.; Hansen C. B.; Nath V.; Ramadass K.; Johnson G. W.; Conrad B. N.; Boyd B. D.; Begnoche J. P.; Beason-Held L. L.; Shafer A. T.; Resnick S. M., Taylor W. D., Price G. R., Morgan V. L., Rogers B. P., Schilling K. G., Landman B. A. PreQual: An automated pipeline for integrated preprocessing and quality assurance of diffusion weighted MRI images. Magn Reson Med, 2021, 86(1):456-470'.format(c+3)) 
    c += 4
    # B0 threshold has to ckecked (in Eddy), and further QC image check (2021/10/7)
    
    # Denoise
    if iDIO_Output['Denoise']:
        method_str.append(r"$\bf{\blacktriangleright\ Signal\ denoising:}$" + ' using ' + r"$\it{dwidenoise}$" + ' (MRtrix3 command) based on random matrix with patch-level Marchenko-Pastur PCA method [{}, {}, {}].'.format(c, c+1,c +2))
        Reference_str.append('[{}] Veraart, J., Novikov, D. S., Christiaens, D., Ades-aron, B., Sijbers, J., Fieremans, E. Denoising of diffusion MRI using random matrix theory. NeuroImage, 2016, 142:394-406'.format(c))
        Reference_str.append('[{}] Veraart, J., Fieremans, E., Novikov, D. S. Diffusion MRI noise mapping using random matrix theory. Magn Reson Med, 2016, 76(5):1582-1593'.format(c+1))
        Reference_str.append('[{}] Cordero-Grande, L., Christiaens, D., Hutter, J., Price, A.N., Hajnal, J.V. Complex diffusion-weighted image estimation via matrix recovery under general noise models. NeuroImage, 2019, 200:391-404'.format(c+2))
        c += 3
    else:
        warning_str.append(r"$\bf{\times\ Images\ (dicom\ image)\ interpolation\ detected}$")
        warning_str.append(r"$\bf{\times\ Denoise\ step\ was\ skipped:}$" + "due image interpolation violates Marchenko-Pastur PCA assumption")


    # Degibbs
    method_str.append(r"$\bf{\blacktriangleright\ Gibbs\ ringing\ removal:}$" + ' using ' + r"$\it{mrdegibbs}$" + ' (MRtrix3 command) with local subvoxel-shifts method [{}].'.format(c))
    Reference_str.append('[{}] Kellner, E, Dhital, B, Kiselev, V. G, Reisert, M. Gibbs-ringing artifact removal based on local subvoxel-shifts. Magn Reson Med, 2016, 76:1574–1581'.format(c))
    warning_str.append(r"$\bf{\times\ Caution\ for\ Gibbs\ ringing\ removel:}$" + ' partial Fourier acquisition may lead to suboptimal results, please check corrected output images and use it with caution.')
    gibbsc = c
    c += 1
    

    # Drift
    if iDIO_Output['Drift']:
        method_str.append(r"$\bf{\blacktriangleright\ Signal\ drift\ correction:}$" + ' using ' + r"$\it{linear\ correction}$" + ' adapted from the released script by Vos S.B [{}].'.format(c))
        Reference_str.append('[{}] Vos S. B.; Tax C. M.; Luijten P. R.; Ourselin S.; Leemans A.; Froeling M. The importance of correcting for signal drift in diffusion MRI. Magn Reson Med, 2017, 77(1):285-299'.format(c))
        c += 1
    else:
        warning_str.append(r"$\bf{\times\ Drifting\ correction\ was\ skipped:}$" +' no sufficient b0 Images (less than three) in the acquired image, three or more b0 images interleaved across the dwi acquisition suggested (e.g. 1 b0 per 8-10 volumes)')

    # PEdir
    if iDIO_Output['RPEcor']:
        method_str.append(r"$\bf{\blacktriangleright\ Suceptibility-induced\ distortion,\ eddy\ current,\ and\ subject\ movement\ correction:}$" + ' using ' + r"$\it{topup}$" + ' and ' + r"$\it{eddy}$" + ' (FSL commands) [{}, {}, {}].'.format(c, c+1, c+2))
        Reference_str.append('[{}] Andersson J. L. R., Skare S., Ashburner J. How to correct susceptibility distortions in spin-echo echo-planar images: application to diffusion tensor imaging. NeuroImage, 2003, 20(2):870-888'.format(c))
        Reference_str.append('[{}] Smith S. M., Jenkinson M., Woolrich M. W., Beckmann C. F., Behrens T. E. J., Johansen-Berg H., Bannister P. R., De Luca M., Drobnjak I., Flitney D. E., Niazy R., Saunders J., Vickers J., Zhang Y., De Stefano N.,Brady J. M., Matthews P. M. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 2004, 23(S1):208-219'.format(c+1))
        Reference_str.append('[{}] Andersson J. L. R. and Sotiropoulos S. N. An integrated approach to correction for off-resonance effects and subject movement in diffusion MR imaging. NeuroImage, 2016, 125:1063-1078'.format(c+2))
        c += 3
    else:
        method_str.append(r"$\bf{\blacktriangleright\ Eddy\ current,\ and\ subject\ movement\ correction:}$" + ' using ' + r"$\it{eddy}$" + ' (FSL command) [{}].'.format(c))
        Reference_str.append('[{}] Andersson J. L. R. and Sotiropoulos S. N. An integrated approach to correction for off-resonance effects and subject movement in diffusion MR imaging. NeuroImage, 2016, 125:1063-1078'.format(c))
        warning_str.append(r"$\bf{\times\ Susceptibility\ distortion\ correction\ skipped:}$" + ' single phase encoding dwi was detected, two opposite phase encoding dwi are needed')
        c += 1 
    
    # slice to volume correction
    if iDIO_Output['S2V']:
        method_str.append(r"$\bf{\blacktriangleright\ Within-volume\ (slice-to-volume)\ movement\ were\ considered:}$" + ' using ' + r"$\it{--mporder}$" + ' (FSL eddy option) [{}].'.format(c))
        Reference_str.append('[{}] Andersson J. L. R., Graham M. S., Drobnjak I., Zhang H., Filippini N. Bastiani M. Towards a comprehensive framework for movement and distortion correction of diffusion MR images: Within volume movement. NeuroImage, 2017, 152:450-466.'.format(c))
        c += 1
    # BiasCorrection
    method_str.append(r"$\bf{\blacktriangleright\ B1\ field\ inhomogeneity\ correction:}$" + ' using ' + r"$\it{dwibiascorrect}$" + ' (MRtrix3 command) with ants option [{}].'.format(c))
    Reference_str.append('[{}] Tustison, N., Avants, B., Cook, P., Zheng, Y., Egan, A., Yushkevich, P., Gee, J. N4ITK: Improved N3 Bias Correction. IEEE Trans Med Imaging, 2010, 29:1310-1320'.format(c))
    antsc = c
    c += 1

    # Resize
    if iDIO_Output['Resize']:
        method_str.append(r"$\bf{\blacktriangleright\ Images\ resized:}$" + ' resized into {} isotropic voxels.'.format(iDIO_Output['ResizeVoxelSize']))

    if iDIO_Output['ResizeWarning']:
        warning_str.append(r"$\bf{\times\ Suggest\ to\ do\ the\ resize\ step\ (native\ dwi\ voxel\ size\ was\ not\ isotropic)}$")

    # for t1 preprocessing:
    if iDIO_Output['CSDproc'] or iDIO_Output['Tracking'] or iDIO_Output['DTIFIT']:
        method_str.append(r"$\bf{\blacktriangleright\ T1W\ image\ preprocessing:}$" + ' Gibbs ringing removal (' + r"$\it{mrdegibbs}$" + ' MRtrix3 command)'+ ', B1 field inhomogeneity correction (' + r"$\it{N4BiasFieldCorrection}$" + ' ANTs command)' + ', and five-tissue-type (5tt) segmentation (including cortical gray matter, subcortical gray matter, white matter, cerebrospinal fluild and pathological tissue, ' + r"$\it{5ttgen}$" + ' MRtrix3 command with fsl option) [{}, {}, {}].'.format(gibbsc, antsc, c))
        method_str.append(r"$\bf{\blacktriangleright\ T1W\ image\ registratered\ with\ b0\ image:}$" + ' T1W image mask were registered to b0 as analysis mask using boundary-based registration with the segmented white matter (' + r"$\it{BBR}$" + ' FSL command) to generate the transformation matrix from Diffusion-space to T1-space [{}, {}].'.format(c+1, c+2))
        Reference_str.append('[{}] Avants B. B, Yushkevich P., Pluta J., Minkoff D., Korczykowski M., Detre J., Gee J. C. The optimal template effect in hippocampus studies of diseased populations. NeuroImage, 2010, 49(3):2457-66'.format(c))
        Reference_str.append('[{}] Jenkinson, M., Bannister, P., Brady, J. M. and Smith, S. M. Improved Optimisation for the Robust and Accurate Linear Registration and Motion Correction of Brain Images. NeuroImage, 2002, 17(2):825-841'.format(c+1))
        Reference_str.append('[{}] Greve, D. N. and Fischl, B. Accurate and robust brain image alignment using boundary-based registration. NeuroImage, 2009, 48(1):63-72'.format(c+2))

        c += 3

    if iDIO_Output['DTIFIT']:
        method_str.append(r"$\bf{\blacktriangleright\ Diffusion\ Tensor\ image\ estimation:}$" + ' quantitative indices of fractional anisotropy, axial diffusivity, mean diffusivity and radial diffusion maps were calculated using ' + r"$\it{dtifit}$" + ' (FSL command).')

    if iDIO_Output['CSDproc']:
        method_str.append(r"$\bf{\blacktriangleright\ Fiber\ orientation\ density\ function\ (fODF)\ estimation:}$" + ' using a multi-shell multi-tissue constrained spherical deconvolution model with the prior co-registered 5tt image ' + '(using ' + r"$\it{dwi2fod}$"  + ' MRtrix3 commands) [{}].'.format(c))
        method_str.append(r"$\bf{\blacktriangleright\ ODF\ with\ multi-tissue\ informed\ log-domain\ intensity\ normalization:}$" + '\nusing '+ r"$\it{mtnormalise}$" + ' (MRtrix3 commands) [{}, {}].'.format(c+1, c+2))
        Reference_str.append('[{}] Jeurissen, B, Tournier, J. D.; Dhollander, T., Connelly, A., Sijbers, J. Multi-tissue constrained spherical deconvolution for improved analysis of multi-shell diffusion MRI data. NeuroImage, 2014, 103:411-426'.format(c))
        Reference_str.append('[{}] Raffelt, D., Dhollander, T., Tournier, J. D., Tabbara, R., Smith, R. E., Pierre, E., Connelly, A. Bias Field Correction and Intensity Normalisation for Quantitative Analysis of Apparent Fibre Density. In Proc. ISMRM, 2017, 26:3541'.format(c+1))
        Reference_str.append('[{}] Dhollander, T., Tabbara, R., Rosnarho-Tornstrand, J., Tournier, J. D., Raffelt, D., Connelly, A. Multi-tissue log-domain intensity and inhomogeneity normalisation for quantitative apparent fibre density. In Proc. ISMRM, 2021, 29:2472'.format(c+2))
        c += 3

    if iDIO_Output['Tracking']:
        method_str.append(r"$\bf{\blacktriangleright\ White\ matter\ tractography:}$" + ' fiber tracking were performed based on the voxel-wise fODF using anatomically constrained tractography with dynamic seeding iFOD2 algorithm and the spherical-deconvolution informed weighted of tractogram were applied. These could be achieved by using ' + r"$\it{tckgen}$" + ' and ' + r"$\it{tckgentcksift2}$" + ' (MRtrix3 commands) [{}, {}].'.format(c, c+1)) 
        method_str.append(r"$\bf{\blacktriangleright\ Connectivity\ matrices\ reconstruction:}$" + ' AAL3 [{}], HCPMMP [{}], HCPex [{}], Yeo 400 [{}] atlases were utilized to generate the connectivity matrices. To transform the atlases from MRI standard space to the individual native space, T1 image was spatially normalized to the nonlinear ICBM152 template using '.format(c+2, c+3, c+4, c+5)+ r"$\it{antsRegistrationSyNQuick}$" + ' (ANTs command) [{}].'.format(c+6))
        Reference_str.append('[{}] Tournier, J. D., Calamante, F., Connelly, A. Improved probabilistic streamlines tractography by 2nd order integration over fibre orientation distributions. In Proc. ISMRM, 2010, 1670'.format(c))
        Reference_str.append('[{}] Smith, R. E., Tournier, J. D., Calamante, F., Connelly, A. SIFT2: Enabling dense quantitative assessment of brain white matter connectivity using streamlines tractography. NeuroImage, 2015, 119:338-351'.format(c+1))
        Reference_str.append('[{}] Rolls E. T., Huang C. C., Lin C. P., Feng J., Joliot M. Automated anatomical labelling atlas 3. Neuroimage. 2020, 206:116189'. format(c+2))
        Reference_str.append('[{}] Glasser M. F., Coalson T. S., Robinson E. C., Hacker C. D., Harwell J., Yacoub E., Ugurbil K., Andersson J., Beckmann C. F., Jenkinson M., Smith S. M., Van Essen D. C. A multi-modal parcellation of human cerebral cortex. Nature. 2016 Aug 11;536(7615):171-178'.format(c+3))
        Reference_str.append('[{}] Huang C. C., Rolls E. T., Hsu C. C. H., Feng J., Lin C. P. Extensive Cortical Connectivity of the Human Hippocampal Memory System: Beyond the "What" and "Where" Dual Stream Model. Cereb Cortex, 2021, 31(10):4652-4669'.format(c+4))
        Reference_str.append('[{}] Schaefer A., Kong R., Gordon E. M., Laumann T. O., Zuo X. N., Holmes A. J., Eickhoff S. B., Yeo B. T. T. Local-Global Parcellation of the Human Cerebral Cortex from Intrinsic Functional Connectivity MRI. Cereb Cortex, 2018, 28(9):3095-3114'.format(c+5))
        Reference_str.append('[{}] Avants B. B., Epstein C. L., Grossman M., Gee J. C. Symmetric diffeomorphic image registration with cross-correlation: Evaluating automated labeling of elderly and neurodegenerative brain. Med Image Anal, 2008, 12:26–41'.format(c+6))
        c += 7

    if iDIO_Output['LowBonly']:
        warning_str.append(r"$\bf{\times\ Caution\ for\ poor\ constrained\ spherical\ deconvolution\ (CSD)\ estimation:}$" + ' dwi acquisition scheme lack of high b-value (b > 1500 s/' + r'$mm^{2}$' + ') volumes')

    if iDIO_Output['HighBonly']:
        warning_str.append(r"$\bf{\times\ Diffusion\ tensor\ fitting\ (DTI)\ skipped:}$" +' no b-value less than 1500 s/' + r'$mm^{2}$' + ' in this data')

    if iDIO_Output['CNRwarning']:
        warning_str.append(r"$\bf{\times\ Discrepency\ of\ b\ shells:}$" + ' the number of unique b-values (with iDIO B0 threshold and shell epsilon) was not equal to the number of shells determined by FSL eddy. Please check')

    if not len(outlier_warning) == 0:
        warning_str.append(r"$\bf{\times\ Outliers\ detected:}$")
        for ow in outlier_warning:
            warning_str.append(ow)

    mergeMethod_str = r'$\bf{Warning:}$' +'\n{}\n'.format('\n'.join(warning_str))
    mergeMethod_str = mergeMethod_str +'\n' + r'$\bf{Methods\ Summary:}$' + '\n{}'.format('\n'.join(method_str))

    title_vis_file = os.path.join(vis_dir, 'Title.pdf')
    fig = plt.figure(0, figsize=SHARED_VARS.PAGESIZE)
    plt.axis([0, 1, 0, 1])  
    ax = plt.gca()
    ax.set_xticks([])
    ax.set_yticks([])
    plt.subplots_adjust(left=0.025, bottom=0.025, right=0.975, top=0.975, wspace=0, hspace=0)
    plt.text(0, 0.99, title_str, ha='left', va='center', wrap=True, fontsize=10, transform=ax.transAxes)

    t = ax.add_artist(WrapText(0, 0.97, mergeMethod_str, va='top', width=0.72, widthcoords=ax.transAxes, transform=ax.transAxes, linespacing = 1.5))
    # t.set_fontfamily('monospace')
    t.set_fontsize(9)
    plt.axis('off')
    plt.savefig(title_vis_file)
    plt.close()

    # # Output Reference page
    if len(Reference_str) > 22:
        # p1
        # sort_ref = sorted(Reference_str)
        mergeRef_str = r'$\bf{Reference:}$' + '\n{}\n'.format('\n'.join(Reference_str[0:22]))
        Ref_vis_files = [os.path.join(vis_dir, 'Reference_1.pdf')]
        plt.figure(0, figsize=SHARED_VARS.PAGESIZE)
        plt.axis([0, 1, 0, 1])
        ax = plt.gca()
        ax.set_xticks([])
        ax.set_yticks([])
        plt.subplots_adjust(left=0.025, bottom=0.025, right=0.975, top=0.975, wspace=0, hspace=0)
        plt.text(0, 0.99, title_str, ha='left', va='center', wrap=True, fontsize=10)
        # plt.text(-0.025, 0.95, mergeRef_str, ha='left', va='top', wrap=True, fontsize=9)
        t = ax.add_artist(WrapText(0, 0.97, mergeRef_str, ha = 'left', va= 'top', width=0.72, widthcoords=ax.transAxes, transform=ax.transAxes, linespacing = 1.5))
        # t.set_fontfamily('monospace')
        t.set_fontsize(9)
        plt.axis('off')
        plt.savefig(Ref_vis_files[0])
        plt.close()
        # p2 
        mergeRef_str = r'$\bf{Reference:}$' + '\n{}\n'.format('\n'.join(Reference_str[22:len(Reference_str)]))
        Ref_vis_files.append(os.path.join(vis_dir, 'Reference_2.pdf'))
        plt.figure(0, figsize=SHARED_VARS.PAGESIZE)
        plt.axis([0, 1, 0, 1])
        ax = plt.gca()
        ax.set_xticks([])
        ax.set_yticks([])
        plt.subplots_adjust(left=0.025, bottom=0.025, right=0.975, top=0.975, wspace=0, hspace=0)
        plt.text(0, 0.99, title_str, ha='left', va='center', wrap=True, fontsize=10)
        # plt.text(-0.025, 0.95, mergeRef_str, ha='left', va='top', wrap=True, fontsize=9)
        t = ax.add_artist(WrapText(0, 0.97, mergeRef_str, ha = 'left', va= 'top', width=0.72, widthcoords=ax.transAxes, transform=ax.transAxes, linespacing = 1.5))
        # t.set_fontfamily('monospace')
        t.set_fontsize(9)
        plt.axis('off')
        plt.savefig(Ref_vis_files[1])
        plt.close()
    else:
        mergeRef_str = r'$\bf{Reference:}$' + '\n{}\n'.format('\n'.join((Reference_str)))
        Ref_vis_files = [os.path.join(vis_dir, 'Reference.pdf')]
        plt.figure(0, figsize=SHARED_VARS.PAGESIZE)
        plt.axis([0, 1, 0, 1])
        ax = plt.gca()
        ax.set_xticks([])
        ax.set_yticks([])
        plt.subplots_adjust(left=0.025, bottom=0.025, right=0.975, top=0.975, wspace=0, hspace=0)
        plt.text(0, 0.99, title_str, ha='left', va='center', wrap=True, fontsize=10)
        # plt.text(-0.025, 0.95, mergeRef_str, ha='left', va='top', wrap=True, fontsize=9)
        t = ax.add_artist(WrapText(0, 0.97, mergeRef_str, ha = 'left', va= 'top', width=0.72, widthcoords=ax.transAxes, transform=ax.transAxes, linespacing = 1.5))
        # t.set_fontfamily('monospace')
        t.set_fontsize(9)
        plt.axis('off')
        plt.savefig(Ref_vis_files[0])
        plt.close()

    return title_vis_file, Ref_vis_files

# Private function
def _get_eddy_num_std_map(path):
    
    rows = []
    with open(path,'r') as f:
        txt = f.readlines()
        for i in np.arange(1,len(txt)):
            rows.append(_str2float(txt[i].strip('\n ').split(' ')))
    outlier_array = np.array(rows)
    return outlier_array

def _str2float(string):

    row = []
    for i in range(len(string)):
        row.append(float(string[i]))
    return row

def _get_outlier_map(path):

    rows = []
    with open(path,'r') as f:
        txt = f.readlines()
        for i in np.arange(1,len(txt)):
            rows.append(_str2list(txt[i].strip('\n')))
    outlier_array = np.array(rows)
    return outlier_array

def _str2list(string):

    row = []
    for i in range(len(string)):
        if (not np.mod(i,2)):
            row.append(int(string[i]))
    return row

class WrapText(mtext.Text):
    """
    WrapText(x, y, s, width, widthcoords, **kwargs)
    x, y       : position (default transData)
    text       : string
    width      : box width
    widthcoords: coordinate system (default screen pixels)
    **kwargs   : sent to matplotlib.text.Text
    Return     : matplotlib.text.Text artist
    """
    def __init__(self, x=0, y=0, text='', width=0, widthcoords=None, **kwargs):
        mtext.Text.__init__(self, x=x, y=y, text=text, wrap=True, clip_on=False, **kwargs)
        if not widthcoords:
            self.width = width
        else:
            a = widthcoords.transform_point([(0,0),(width,0)])
            self.width = a[1][0]-a[0][0]

    def _get_wrap_line_width(self):
        return self.width
