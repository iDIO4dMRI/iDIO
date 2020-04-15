function mask = drift_brainmask(im,thr,k_size)
% Function to get brainmask for b=0-image to use for signal drift
% estimation and correction (subfunction of correct_signal_drift.m)
% (based on ExploreDTI, www.exploredti.com, b=0-image masking)
% 
% Inputs:
% - im:     3D data set (e.g., the b=0-image).
% - thr:    manual tuning factor (typical value range [0.5 1])
% - k_size:	morphological kernel size (odd integer; e.g., 7) 
%
% Created by Sjoerd Vos (s.vos@ucl.ac.uk)
% Translational Imaging Group, University College London, London, United Kingdom


% Check inputs
if thr==0
    mask = true(size(im));
    return
elseif isinf(thr)
    mask = false(size(im));
    return
end

im = double(im);
im = imfill(im);

% Bound at 99th percentile
B = im;
im = im(:);
im(im==0)=[];
y = prctile(im,99);
im(im>y)=[];
T = median(im(:));

crit = 1;
N = 0;

% Thresholding
while crit && N<100 
    N = N+1;
    T_new = (median(im(im<=T)) + median(im(im>T)))/2;
    crit = T_new ~= T;
    T = T_new;
end
mask = B>T*thr;

% Get largest connected component
[L,NUM] = bwlabeln(mask,6);
SL = L(L~=0);
sd = hist(SL,1:NUM);
[M,I] = max(sd);
mask(L~=I)=0;
mask = imfill(mask,'holes');

% Erode mask with predefined kernel size
se = zeros(k_size,k_size,k_size);
se((k_size+1)/2,(k_size+1)/2,(k_size+1)/2)=1;
se = smooth3(se,'gaussian',[k_size k_size k_size],1);
se = se>=se((k_size+1)/2,(k_size+1)/2,end);
mask = imerode(mask,se)>0;

% Get largest connected component again
[L,NUM] = bwlabeln(mask,6);
SL = L(L~=0);
sd = hist(SL,1:NUM);
[M,I] = max(sd);
mask(L~=I)=0;
% Dilate with same kernel
mask = imdilate(mask,se)>0;

% Fill all in-plane holes in mask
for i=1:size(mask,3)
    mask(:,:,i) = imfill(mask(:,:,i),'holes');
end


% End of function drift_brainmask.m
