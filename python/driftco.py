#!/usr/bin/python
# version 2021/09/23
# Edit: conditional expression in mask generation

import argparse, os, scipy.ndimage
from skimage import measure
import numpy as np
import scipy as sp
import nibabel as nib
import matplotlib.pyplot as plt #visualization 


def parseArguments():
    # Create argument parser

    parser = argparse.ArgumentParser(description='This script provide a function for signal drift correction(current version only support linear fit), which is based on the matlab version (correct_signal_drift.m) created by Sjoerd Vos. For more details, please refer to Vos et al., MRM 2016, in press (doi:10.1002/mrm.26124)')
    # Positional mandatory arguments
    parser.add_argument("Input", help="input nifti file with drift-affected DWI data", type=str)
    # parser.add_argument("Grad_info_path", help="corresponding gradient file in fsl type(b-values", type=str)
    parser.add_argument("B0_info", help="corresponding b0 image volume number(separated with comma), which are utilize in drift-estimation and correction",type=str)
    # parser.add_argument("Bzerothr", help="input Bzero threshold to identified the null images")
    parser.add_argument("Output", help="Output file name", type=str)
    parser.add_argument('-v','--version', action='version', version='driftco v1.0')

    # Parse arguments
    args = parser.parse_args()

    return args

def drift_brainmask(im,thr,k,er_k):
	# function to get brain mask for b- image for signal drift
	# Inputs:
	# - im: 3d data set (b0 image)
	# - thr: manual tuning factor, typical [0.5 1]
	# - k: morphological kernel size (odd integer)
	# - er_k: erosion kernel, typical [3]
	##
    def flood_fill(test_array, four_way=False):
        input_array = np.copy(test_array)
        # Set h_max to a value larger than the array maximum to ensure that the while loop will terminate
        h_max = np.max(input_array * 2.0)
        # Build mask of cells with data not on the edge of the image
        # Use 3x3 square structuring element
        data_mask = np.isfinite(input_array)
        el = np.array([[1, 1, 1], [1, 1, 1], [1, 1, 1]]).astype(np.bool_)
        inside_mask = sp.ndimage.binary_erosion(data_mask, structure=el)
        edge_mask = (data_mask & ~inside_mask)

        # Initialize output array as max value test_array except edges
        output_array = np.copy(input_array)
        output_array[inside_mask] = h_max

        # Array for storing previous iteration
        output_old_array = np.copy(input_array)
        output_old_array.fill(0)

        # Cross structuring element
        if four_way:
            el = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]).astype(np.bool_)
        else:
            el = np.array([[1, 1, 1], [1, 1, 1], [1, 1, 1]]).astype(np.bool_)

        # Iterate until marker array doesn't change
        while not np.array_equal(output_old_array, output_array):
            output_old_array = np.copy(output_array)
            output_array = np.maximum(input_array, sp.ndimage.grey_erosion(output_array, footprint=el))
        return output_array

    def erode_kernel(k):
        se = np.zeros([k, k, k])
        se[(k+1)//2-1, (k+1)//2-1, (k+1)//2-1]=1
        se = np.around(scipy.ndimage.gaussian_filter(se, 1, mode='constant'),decimals=4)
        se = (se>=se[(k+1)//2-1,(k+1)//2-1,-1])*1
        return se

    # Get mask and erode once for each image
    #bound at 99th percentile
    im_fill = np.zeros([im.shape[0],im.shape[1],im.shape[2]])
    for x in range(0, im.shape[2]):
        im_fill[:,:,x] = flood_fill(im[:,:,x])

    B = im_fill
    im = im.reshape(im.shape[0]*im.shape[1]*im.shape[2],1)
    im = np.delete(im,np.where(im<0))
    y = np.percentile(im,99)
    im = np.delete(im,np.where(im>y))
    T = np.median(im)

    # thresholding
    crit = True
    N = 0

    while crit and N<100:
        N= N+1
        T_new = np.median(im[im<=T]) + np.median(im[im>T])/2
        crit = T_new !=T
        T=T_new
    mask = B>T*thr*1

    # Get largest connected component
    [L,NUM] = measure.label(mask, connectivity=1,return_num=True)
    SL = L[L!=0];
    [sd, binedge] = np.histogram(SL, bins=np.max(SL)-1)
    [I] = np.where(sd==np.max(sd));
    mask=mask*(L==binedge[I[0]])*1
    mask_fill = np.zeros([mask.shape[0],mask.shape[1],mask.shape[2]])
    for x in range(0, mask.shape[2]):
        mask_fill[:,:,x] = flood_fill(mask[:,:,x],four_way=True)

    # Erode mask with predefined kernel size
    se_2 = erode_kernel(k)
    mask_fill = scipy.ndimage.binary_erosion(mask_fill, se_2)

    #Get largest connected component again (if image only one component, pass this part)
    [L,NUM] = measure.label(mask_fill, connectivity=1,return_num=True)
    if np.max(L) != 1:
        SL = L[L!=0];
        [sd, binedge] = np.histogram(SL, bins=np.max(SL)-1)
        [I] = np.where(sd==np.max(sd));
        mask_fill=mask_fill*(L==binedge[I[0]])*1
        mask_fill = scipy.ndimage.binary_dilation(mask_fill, se_2) #dilate with same kernel

        #fill all in-plan holes in the mask
        for x in range(0, mask_fill.shape[2]):
            mask_fill[:,:,x] = flood_fill(mask_fill[:,:,x],four_way=True)

        # create gaussian kernal first for last erosion
        se = erode_kernel(er_k)
        mask_fill = scipy.ndimage.binary_erosion(mask_fill, se)

    return mask_fill

# ouput arguments
if __name__ == '__main__':
    args = parseArguments()
    # Load B0 info
    b_to_use = [int(x) for x in args.B0_info.split(",")]

    # Load Grad Info
    # grad_info = np.loadtxt(args.Grad_info_path)

    # Load image
    raw_info = nib.load(args.Input)
    raw = np.array(nib.load(args.Input).dataobj)
    nr_ims = raw.shape[3]

    # Fix parameters for generating brain mask
    er_k = 3
    k = 5
    mask_thr = 0.8

    # Get all selected images
    ims_to_use = raw[:,:,:,b_to_use]

    # Get mask for each image
    mask = np.zeros([raw.shape[0],raw.shape[1],raw.shape[2],len(b_to_use)])
    for x in range(0,len(b_to_use)):
        mask[:,:,:,x]=drift_brainmask(ims_to_use[:,:,:,x],mask_thr,k,er_k)

    # Get mean intensities of each b0 within the mask
    ints = np.zeros([len(b_to_use)])
    n = len(b_to_use)
    x = range(1,nr_ims+1)
    for i in range(0, len(b_to_use)):
        t = ims_to_use[:,:,:,i]
        ints[i] = np.mean(t[np.where(mask[:,:,:,i]==1)])
    j=0
    intsall = np.zeros(nr_ims)
    for i in range(0,nr_ims):
        t = raw[:,:,:,i]
        intsall[i] = np.mean(t[np.where(mask[:,:,:,j]==1)])
        if j<len(b_to_use)-1 and i>= b_to_use[j+1]:
            j=j+1    

    # do linear fit correction
    drift_fit_l = np.polyfit(b_to_use,ints,1)
    corr_l = x*drift_fit_l[0]+drift_fit_l[1]
    decr_prc = (1-corr_l[nr_ims-1]/corr_l[0])*100
    norm_val = drift_fit_l[1]
    # get correction for each image
    corr_fac = norm_val/corr_l
    # apply correction to each volume
    DWI_corr = np.zeros(raw.shape)
    for d in range(0, DWI_corr.shape[3]):
        DWI_corr[:,:,:,d] = raw[:,:,:,d]*corr_fac[d]
    #get b0 from corrected data
    mean_corr_int = np.zeros([len(b_to_use)])
    for i in range(0, len(b_to_use)):
        t = DWI_corr[:,:,:,b_to_use[i]]
        mean_corr_int[i] = np.mean(t[np.where(mask[:,:,:,i]==1)])
    j=0
    mean_corr_intsall = np.zeros(nr_ims)
    for i in range(0,nr_ims):
        t = DWI_corr[:,:,:,i]
        mean_corr_intsall[i] = np.mean(t[np.where(mask[:,:,:,j]==1)])
        if j<len(b_to_use)-1 and i>= b_to_use[j+1]:
            j=j+1

    # save to image
    SaveDWI = nib.Nifti1Image(DWI_corr,raw_info.affine, raw_info.header)
    nib.save(SaveDWI, args.Output)

    Savepath = os.path.split(args.Output)
    # show corrected intensities of b0
    f=plt.figure(figsize=(10,8))
    # plot raw intensities
    plt.plot(b_to_use, ints, 'ro',label='Uncorrected')
    # plot corrected intensities and the fit line
    plt.plot(b_to_use, mean_corr_int,'bo',label='Corrected')
    plt.plot(corr_l,'b',label='Linear fit')
    #add dashed line at 100%
    plt.plot([0, nr_ims],[norm_val, norm_val],'k--', label='baseline')
    plt.legend(loc='best', fontsize='large')
    plt.xlim([-2, nr_ims+2])
    plt.ylabel('Signal intensity')
    plt.xlabel('DWI volume')
    plt.title("An estimated " + str(round(decr_prc,2)) +"% signal loss from first to last image")
    # plt.show()
    plt.savefig(Savepath[0]+'/Drifting_Correction_B0only.png')

    with open(Savepath[0]+'/Drifting_val.csv', 'w') as str_fobj:
        str_fobj.write(str(round(decr_prc,4)))


    # show corrected intensities of all images
    f=plt.figure(figsize=(10,8))
    plt.plot(b_to_use, ints, 'ro',label='Uncorrected B0')
    plt.plot(x,intsall,'r-',label='Uncorrected')
    plt.plot(b_to_use, mean_corr_int, 'bo', label='Corrected B0')
    plt.plot(x, mean_corr_intsall, 'b-', label='Corrected')
    plt.plot([0, nr_ims],[norm_val, norm_val],'k--', label='baseline')
    plt.xlim([-2, nr_ims+2])
    plt.ylabel('Signal intensity')
    plt.xlabel('DWI volume')
    plt.title("Drifting_Corrected_Data")
    plt.legend(loc='best', fontsize='large')
    # plt.show()
    plt.savefig(Savepath[0]+'/Drifting_Correction_allData.png')