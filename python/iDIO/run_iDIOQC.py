#!/usr/bin/python
# version: 2021/09/29
# Credit : Modify from PreQual: https://github.com/MASILab/PreQual (by Leon Cai and Qi Yang, MASI Lab, Vanderbilt University)
# iDIO QC main script

# Set Up

import sys, os, glob, time, re
from io import StringIO
import argparse
import numpy as np

# iDIO combined PreQual libraries
import preproc
import stats
import utils
import iDIOvis
from vars import SHARED_VARS

def parseArguments():
    # Create argument parser
    parser = argparse.ArgumentParser(description='This script aims to generate the QA report for iDIO diffusion preprocessing. We embeded functions from PreQual created by Leion Cai and Qi Yang. For more details, please refer to Cai et al. MRM 2021, in press (doi: 10.1002/mrm.28678.)')
    # Positional mandatory arguments
    parser.add_argument('subj_dir', help='Path of the iDIO PreprocDir (with directories from step 1 to 6)')
    # Template directory which include JHU-ICBM-FA-1mm.nii.gz and JHU-ICBM-labels-1mm.nii.gz
    parser.add_argument('template_dir', help='Path of the Template directory (include JHU-ICBM-FA-1mm.nii.gz and JHU-ICBM-labels-1mm.nii.gz)')
    parser.add_argument('project_name', help='Project Name')

    args = parser.parse_args()
    # Parse arguments
    return args

# run pipeline
def iDIO_QC(subj_dir, template_dir, project_name):

    print('*************************************************')
    print('***      iDIO QC: QC STATISTICAL ANALYSES     ***')
    print('*************************************************')
    # print('Processing Dir: {}'.format(subj_dir))
    ti = time.time()
    subj_dir = os.path.abspath(subj_dir)
    # Setting path
    # initialize iDIO output dictionary
    iDIO_Output ={
        'Denoise':[],
        'Drift':[],
        'RPEcor':[],
        'S2V':[],
        'Resize':[],
        'ResizeVoxelSize':[],
        'ResizeWarning':[],
        'HighBonly':[],
        'LowBonly':[],
        'DTIFIT':[],
        'CSDproc':[],
        'Tracking':[],
    }
    # load raw data (for visualization comparison)
    dwi_files, bvals_files, bvecs_files, pe_dirs, pe_axis, raw_merge_dwi_file = utils.load_config(subj_dir)

    if os.path.exists(subj_dir + '/Preprocessed_data/dwi_preprocessed_resized.nii.gz'):
        dwi_preproc_file = subj_dir + '/Preprocessed_data/dwi_preprocessed_resized.nii.gz'
        bvals_preproc_file = subj_dir + '/Preprocessed_data/dwi_preprocessed_resized.bval'
        bvecs_preproc_file = subj_dir + '/Preprocessed_data/dwi_preprocessed_resized.bvec'
        iDIO_Output['Resize'] = True
        _, a, _ = utils.load_nii(dwi_preproc_file)
        iDIO_Output['ResizeVoxelSize'] = int(abs(a[0][0]))
    else:
        dwi_preproc_file = subj_dir + '/Preprocessed_data/dwi_preprocessed.nii.gz'
        bvals_preproc_file = subj_dir + '/Preprocessed_data/dwi_preprocessed.bval'
        bvecs_preproc_file = subj_dir + '/Preprocessed_data/dwi_preprocessed.bvec'
        iDIO_Output['Resize'] = False;
    
    _, a, _ = utils.load_nii(dwi_preproc_file)
    if (int(abs(a[0][0]))==int(abs(a[1][1]))) & (int(abs(a[0][0]))==int(abs(a[2][2]))):
        pass
    else:
        iDIO_Output['ResizeWarning'] = True

    mask_file = subj_dir + '/Preprocessed_data/T1w_mask_inDWIspace.nii.gz'
    eddy_dir = subj_dir + '/3_EddyCo'
    out_dir = utils.make_dir(subj_dir, '8_QC')
    tmp_dir = utils.make_dir(out_dir,'TMP')

    bvals_checked_files = glob.glob(subj_dir + '/2_BiasCo/*.bval')
    bvecs_checked_files = glob.glob(subj_dir + '/2_BiasCo/*.bvec')

    fa_file = glob.glob(subj_dir + '/5_DTIFIT/*FA.nii.gz')
    v1_file = glob.glob(subj_dir + '/5_DTIFIT/*V1.nii.gz')

    if os.path.exists(fa_file[0]):
        iDIO_Output['DTIFIT'] = True
    else:
        iDIO_Output['DTIFIT'] = False

    odf_file = glob.glob(subj_dir + '/6_CSDpreproc/S1_Response/odf_wm_norm.mif')
    if os.path.exists(odf_file[0]):
        iDIO_Output['CSDproc'] = True
    else:
        iDIO_Output['CSDproc'] = False

    # Eddy mask dir
    if os.path.exists(subj_dir + '/3_EddyCo/Mean_Unwarped_Images_Brain_mask.nii.gz'):
        eddy_mask_file = subj_dir + '/3_EddyCo/Mean_Unwarped_Images_Brain_mask.nii.gz' 
        iDIO_Output['RPEcor'] = True
    else:
        eddy_mask_file = subj_dir + '/3_EddyCo/bet_Brain_mask.nii.gz'
        iDIO_Output['RPEcor'] = False

    # Create BPV mask by T1 FAST result
    BPV_mask_file = stats.BPV_mask(mask_file, subj_dir, tmp_dir)

    # load eddy results
    motion_dict, motion_stats_out_list = stats.motion(eddy_dir, tmp_dir)
    EC_dict, EC_stats_out_list = stats.eddy_current(eddy_dir, tmp_dir)
    # Due to the resize, mask is not in the same space as eddy output
    # Regrid if needed
    a, _, _ = utils.load_nii(eddy_mask_file)
    b, _, _ = utils.load_nii(mask_file)
    if a.shape == b.shape:
        cnr_mask = mask_file
    else:
        regrid_cmd = 'mrgrid {} regrid {} -size {},{},{}'.format(mask_file, tmp_dir + '/cnr_mask.nii.gz', a.shape[0], a.shape[1], a.shape[2])
        utils.run_cmd(regrid_cmd)
        cnr_mask = tmp_dir + '/cnr_mask.nii.gz'

    # # CNR form eddy    
    cnr_dict, bvals_preproc_shelled, cnr_stats_out_list, cnr_warning_str = stats.cnr(bvals_preproc_file, cnr_mask, eddy_dir, tmp_dir, shells=[])
    # if cnr_warning_str != '':
    #     warning_strs.append(cnr_warning_str)


    #########################
    # Generate component PDFs

    # P.2 pedir.pdf : show the phase encoding images (suppose two (phase) in same axis only image)
    pedir_vis_file = iDIOvis.vis_pedir(dwi_files, bvals_files, pe_axis, pe_dirs, out_dir)

    # P.3 Denoise : show the noise residual map (seperate with b shell)
    if len(glob.glob(subj_dir + '/2_BiasCo/*-denoise.nii.gz')) !=0:
        denoise_file = glob.glob(subj_dir + '/2_BiasCo/*-denoise.nii.gz')[0]
        Residual_file = subj_dir + '/2_BiasCo/Res.nii.gz'
        res_file = utils.Residual(raw_merge_dwi_file, denoise_file, Residual_file)
        res_vis_file = iDIOvis.vis_noise_comp(raw_merge_dwi_file, res_file, denoise_file, bvals_preproc_file, out_dir)
        iDIO_Output['Denoise'] = True
    else:
        # print('No denoise image were found')
        res_vis_file = ''
        iDIO_Output['Denoise'] = False

    # P.4 degibbs.pdf
    # generate a gain file without prenormalize
    dwi_degibbs_files = glob.glob(subj_dir + '/2_BiasCo/*deGibbs.nii.gz')
    dwi_merge_bval = glob.glob(subj_dir + '/2_BiasCo/*.bval')

    if len(glob.glob(subj_dir + '/2_BiasCo/*-denoise.nii.gz')) !=0:
        dwi_merge_files = glob.glob(subj_dir + '/2_BiasCo/*-denoise.nii.gz')
    else:
        dwi_merge_files = [raw_merge_dwi_file]

    prenorm_dir = utils.make_dir(tmp_dir, 'GAIN_CHECK')
    dwi_prenorm_files, dwi_prenorm_gains, dwi_prenorm_bins, dwi_input_hists, dwi_prenormed_hists = utils.dwi_norm(dwi_degibbs_files, dwi_merge_bval, prenorm_dir)
    degibbs_vis_file = iDIOvis.vis_degibbs(dwi_merge_files, dwi_merge_bval, dwi_degibbs_files, dwi_prenorm_gains, out_dir)

    # P.5 DriftCo 
    if os.path.exists(subj_dir + '/2_BiasCo/Drifting_Correction_B0only.png'):
        png_path = subj_dir + '/2_BiasCo/'
        drift_vis_file = iDIOvis.vis_drift(png_path, out_dir)
        iDIO_Output['Drift'] = True
    else:
        # print('No drift correction image were found')
        drift_vis_file = ''
        iDIO_Output['Drift'] = False

    # P.7 mask visualization
    probable_mask_file, improbable_voxels_file, percent_improbable = utils.dwi_improbable_mask(mask_file, dwi_preproc_file, bvals_preproc_file, tmp_dir + '/MASK')

    preproc_vis_file = iDIOvis.vis_preproc_mask(dwi_files, bvals_files, dwi_preproc_file, bvals_preproc_file, eddy_mask_file, mask_file, percent_improbable, BPV_mask_file, pe_axis, pe_dirs, out_dir)

    # P.8 Bias field correction
    if os.path.exists(glob.glob(subj_dir + '/3_EddyCo/*-EddyCo.nii.gz')[0]) and os.path.exists(glob.glob(subj_dir + '/3_EddyCo/*-EddyCo-unbiased.nii.gz')[0]) and os.path.exists(glob.glob(subj_dir + '/3_EddyCo/*BiasField.nii.gz')[0]):
        wobias_file = glob.glob(subj_dir + '/3_EddyCo/*-EddyCo.nii.gz')[0]
        unbiased_file = glob.glob(subj_dir + '/3_EddyCo/*-EddyCo-unbiased.nii.gz')[0]
        BiasField = glob.glob(subj_dir + '/3_EddyCo/*BiasField.nii.gz')[0]
        bias_vis_file = iDIOvis.vis_bias(wobias_file, BiasField, unbiased_file, bvals_preproc_file, out_dir)
    else:
        print('No BiasField image were found')
        bias_vis_file = ''


    # P.9 gradeient check 
    gradcheck_vis_file = iDIOvis.vis_gradcheck(bvals_checked_files, bvecs_checked_files, bvals_preproc_file, bvecs_preproc_file, out_dir)

    # P.10 SNR/CNR map with Raw b0 SNR output
    dwi_cnr_files, cnr_stats_out_list = iDIOvis.vis_dwi(dwi_preproc_file, bvals_preproc_shelled, mask_file, cnr_dict, out_dir)

    # Calculate Raw data SNR and outlier percentage
    bvals = np.sort(np.unique(bvals_preproc_shelled))
    stats_out_list = []

    for i in range(len(bvals)):

        bvals_shelled_file = StringIO(' '.join([str(bval) for bval in bvals_preproc_shelled]))

        bX = bvals[i]
        if bX == 0:
            bXs_file, num_bXs, _ = utils.dwi_extract(raw_merge_dwi_file, bvals_shelled_file, tmp_dir, target_bval=bX, first_only=False)
            std_cmd = 'fslmaths {} -Tmean {}'.format(bXs_file, tmp_dir + '/Raw_b0mean.nii.gz')
            utils.run_cmd(std_cmd)
            std_cmd = 'fslmaths {} -Tstd {}'.format(bXs_file, tmp_dir + '/Raw_b0std.nii.gz')
            utils.run_cmd(std_cmd)
            snr_cmd = 'fslmaths {} -div {} {}'.format(tmp_dir + '/Raw_b0mean.nii.gz', tmp_dir + '/Raw_b0std.nii.gz', tmp_dir + '/Raw_SNR.nii.gz')
            utils.run_cmd(snr_cmd)
            snr_img, _, _ = utils.load_nii(tmp_dir + '/Raw_SNR.nii.gz', ndim=3)
            mask_img, _, _ = utils.load_nii(cnr_mask, dtype='bool', ndim=3)
            snr = np.nanmedian(snr_img[mask_img])
            bvals_shelled_file.close()
            stats_out_list.append('Raw_b{}_median_{},{}'.format(bX, 'snr' , snr))

    # save stats cvs results
    for index, cnrlish in enumerate(cnr_stats_out_list):
        stats_out_list.append(cnrlish)

    # P.6 motion results by eddy (with preprocessed image)
    stats_vis_file, outlier_percentage = iDIOvis.vis_stats(dwi_preproc_file, bvals_preproc_shelled, mask_file, motion_dict, EC_dict, eddy_dir, out_dir)

    # Load S2V information 
    f = open(glob.glob(subj_dir + '/3_EddyCo/*.eddy_values_of_all_input_parameters')[0],'r')
    for line in f:
        if re.search('--mporder',line):
            s2v = line
            s2v = s2v.split('=')[1]
            s2v = int(s2v.split('\n')[0])

    iDIO_Output['S2V'] = s2v>0

    # load drift and output stats -> need to add with outlier percentage 
    stats.stats_out(subj_dir + '/2_BiasCo/Drifting_val.csv', motion_stats_out_list, EC_stats_out_list, stats_out_list, outlier_percentage, percent_improbable, out_dir)

    # identify shells
    uniq_b = np.unique(bvals_preproc_shelled)
    if len(uniq_b) == 2:
        if min(uniq_b[np.where(uniq_b !=0)]) > 1500:
            iDIO_Output['HighBonly'] = True
            iDIO_Output['LowBonly'] = False
        else:
            iDIO_Output['HighBonly'] = False
            iDIO_Output['LowBonly'] = True
    elif len(np.unique(bvals_preproc_shelled)) > 2:
        if min(uniq_b[np.where(uniq_b !=0)]) < 1500 and max(uniq_b[np.where(uniq_b !=0)]) > 1500:     
            iDIO_Output['HighBonly'] = False
            iDIO_Output['LowBonly'] = False
        elif max(uniq_b[np.where(uniq_b !=0)]) < 1500:
            iDIO_Output['HighBonly'] = False
            iDIO_Output['LowBonly'] = True
        elif max(uniq_b[np.where(uniq_b !=0)]) > 1500:
            iDIO_Output['HighBonly'] = True
            iDIO_Output['LowBonly'] = False

    # P.11 CSD_vis_file
    # Registration for visualizaion and localize CC for visualization (using resgitration info when S7 is done)
    if os.path.exists(subj_dir + '/7_NetworkProc/Reg_matrix/T12MNI_1InverseWarp.nii.gz'):
        warp_cmd = 'WarpImageMultiTransform 3 {} {} -R {} -i {} {} --use-NN'.format(template_dir + '/JHU-ICBM152-labels-1mm.nii.gz', tmp_dir + '/TractAtlas_inT1.nii.gz',subj_dir + '/Preprocessed_data/T1w_preprocessed.nii.gz', subj_dir + '/7_NetworkProc/Reg_matrix/T12MNI_0GenericAffine.mat', subj_dir + '/7_NetworkProc/Reg_matrix/T12MNI_1InverseWarp.nii.gz' )
        utils.run_cmd(warp_cmd)
        warp_cmd = 'mrtransform {} {} -linear {} -template {} -interp nearest -force'.format(tmp_dir + '/TractAtlas_inT1.nii.gz', tmp_dir + '/TractAtlas_inDWI.nii.gz', subj_dir + '/4_T1preproc/Reg_matrix/str2epi.txt', dwi_preproc_file)
        utils.run_cmd(warp_cmd)
        atlas2subj_img, _, _ = utils.load_nii(tmp_dir + '/TractAtlas_inDWI.nii.gz', ndim=3)
        # cc_genu_val = 3;cc_splenium_val = 5 # taken from label.txt
        cc_index = np.logical_or(atlas2subj_img == 3, atlas2subj_img == 5)
        cc_locs = np.column_stack(np.where(cc_index))
        cc_center_voxel = (np.nanmean(cc_locs[:, 0]), np.nanmean(cc_locs[:, 1]), np.nanmean(cc_locs[:, 2]))
        iDIO_Output['Tracking'] = True
    elif len(fa_file) != 0:
        atlas2subj_file, cc_center_voxel = stats.scalar_info(fa_file[0], tmp_dir, template_dir)
        iDIO_Output['Tracking'] = False
    elif os.path.exists(subj_dir + '/6_CSDpreproc/S1_Response/odf_wm_norm.mif'):
        # Generate DEC data and mean DEC
        dec_file = subj_dir + '/6_CSDpreproc/S1_Response/DEC.nii.gz'
        dec_cmd = 'fod2dec {} {}'.format(subj_dir + '/6_CSDpreproc/S1_Response/odf_wm_norm.mif -force', dec_file)
        utils.run_cmd(dec_cmd)
        mean_DEC_file = subj_dir + '/6_CSDpreproc/S1_Response/mean_DEC.nii.gz'
        dec_cmd = 'mrmath {} mean {} -axis 3 -force'.format(subj_dir + '/6_CSDpreproc/S1_Response/DEC.nii.gz', mean_DEC_file)
        utils.run_cmd(dec_cmd)
        atlas2subj_file, cc_center_voxel = stats.scalar_info(mean_DEC_file, tmp_dir, template_dir)
        iDIO_Output['Tracking'] = False

    if 'cc_center_voxel' in locals():
        if os.path.exists(subj_dir + '/6_CSDpreproc') and os.path.exists(subj_dir + '/5_DTIFIT'):
            glyphODF_vis_file = iDIOvis.vis_glyphs(fa_file, odf_file, cc_center_voxel, out_dir)
        elif os.path.exists(subj_dir + '/6_CSDpreproc/S1_Response/mean_DEC.nii.gz'):
            glyphODF_vis_file = iDIOvis.vis_glyphs([subj_dir + '/6_CSDpreproc/S1_Response/mean_DEC.nii.gz'], odf_file, cc_center_voxel, out_dir)
        else:
            glyphODF_vis_file = ''
    else:
        glyphODF_vis_file = ''

    basename = os.path.basename(subj_dir)

    # P.12 DEC_vis_file 
    if len(glob.glob(subj_dir + '/5_DTIFIT/*_DEC.nii.gz')) != 0:
        dec_file = glob.glob(subj_dir + '/5_DTIFIT/*_DEC.nii.gz')[0]
        dec_vis_file = iDIOvis.vis_slice(dec_file, out_dir, 'DEC')
    elif len(fa_file) != 0:
        # Generate DEC data    
        
        dec_file = subj_dir + '/5_DTIFIT/' + basename +'_DEC.nii.gz'
        dec_cmd = 'fslmaths {} -mul {} {}'.format(fa_file[0], v1_file[0], dec_file)
        utils.run_cmd(dec_cmd)
        dec_vis_file = iDIOvis.vis_slice(dec_file, out_dir, 'DEC')
    else:
        dec_vis_file=''

    # P.13 SSE_vis_file
    if len(glob.glob(subj_dir + '/5_DTIFIT/*_sse.nii.gz')) != 0:
        sse_file = glob.glob(subj_dir + '/5_DTIFIT/*_sse.nii.gz')[0]
        sse_vis_file = iDIOvis.vis_slice(sse_file, out_dir, 'SSE')
    elif os.path.exists(fa_file[0]):
        # Generate SSE data in TMP dir
        sse_file = subj_dir + '/5_DTIFIT/' + basename +'_sse.nii.gz'
        sse_cmd = 'dtifit -k {} -o {} -m {} -r {} -b {} --sse'.format(subj_dir + '/5_DTIFIT/' + basename + '-preproc-lowb-data.nii.gz', tmp_dir + '/' + basename, mask_file, subj_dir + '/5_DTIFIT/' + basename + '-preproc-lowb-data.bvec', subj_dir + '/5_DTIFIT/' + basename + '-preproc-lowb-data.bval')
        move_cmd = 'mv {} {}'.format(tmp_dir + '/' + basename +'_sse.nii.gz', subj_dir + '/5_DTIFIT/')
        utils.run_cmd(sse_cmd)
        utils.run_cmd(move_cmd)
        sse_vis_file = iDIOvis.vis_slice(sse_file, out_dir, 'SSE')
    else:
        sse_vis_file=''

    # P.14 Improbable_voxel_file
    if len(fa_file) != 0:
        Improbable_voxel_vis_file = iDIOvis.vis_overlap_slice(fa_file[0], improbable_voxels_file, out_dir, percent_improbable)
    elif os.path.exists(subj_dir + '/6_CSDpreproc/S1_Response/mean_DEC.nii.gz'):
        mean_DEC_file = subj_dir + '/6_CSDpreproc/S1_Response/mean_DEC.nii.gz'
        Improbable_voxel_vis_file = iDIOvis.vis_overlap_slice(mean_DEC_file, improbable_voxels_file, out_dir, percent_improbable)
    else:
        Improbable_voxel_vis_file=''

    # Output P.1 - Reference/Option summary
    # Check Preprocessed steps
    
    # if os.
    title_vis_file, Ref_vis_file = iDIOvis.vis_title(iDIO_Output, out_dir)


    # Combine component PDFs
    vis_files = []
    vis_files.append(title_vis_file)
    for ref_vis in Ref_vis_file:
        vis_files.append(ref_vis)
    vis_files.append(pedir_vis_file)
    for ref_vis in Ref_vis_file:
        vis_files.append(ref_vis)
    vis_files.append(degibbs_vis_file)
    vis_files.append(drift_vis_file)
    vis_files.append(stats_vis_file)
    vis_files.append(bias_vis_file)
    vis_files.append(preproc_vis_file)
    vis_files.append(gradcheck_vis_file)
    for dwi_vis in dwi_cnr_files:
        vis_files.append(dwi_vis)
    vis_files.append(glyphODF_vis_file)
    vis_files.append(dec_vis_file)
    vis_files.append(sse_vis_file)
    vis_files.append(Improbable_voxel_vis_file)
    pdf_file = utils.merge_pdfs(vis_files, project_name + '_QC', out_dir)
    utils.remove_dir(tmp_dir)

    tf = time.time()
    dt = round(tf - ti)

    print('************************************')
    print('***      PDF SAVED ({:05d}s)     ***'.format(dt))
    print('************************************\n')

if __name__ == '__main__':
   # for help function
    args = parseArguments()
   # Run function
    iDIO_QC(args.subj_dir, args.template_dir, args.project_name)