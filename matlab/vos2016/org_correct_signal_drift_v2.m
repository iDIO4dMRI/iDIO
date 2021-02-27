function correct_signal_drift_v2(file_in, grad_info_file, b0var, method,file_out)
% Function to correct for signal drift in diffusion-weighted MRI data
% as described in Vos et al., MRM 2016, in press (doi:)
% 
% Inputs:
% - file_in:        nifti file with drift-affected DWI data
% - grad_info_file: corresponding gradient information
%                       (b-values, gradient vectors (not FSL-format), or b-matrix)
% - file_out:       filename that drift-corrected data is to be saved to
%
% Created by Sjoerd Vos (s.vos@ucl.ac.uk)
% Translational Imaging Group - Centre for Medical Image Computing
% University College London, London, United Kingdom


% Set drift correction method - options are 'quadratic' or 'linear'
% drift_method = 'linear'; 
% drift_method = 'quadratic'; 
% drift_method = 'gaussian';
% drift_method = 'multilinear';
drift_method = method;

% Show plot of original and corrected signal intensities?
show_intensities = true;

% Set b-value to use in drift-estimation and correction - only works for b-matrix or b-values input
% WARNING: a brain mask is created for each used image, and for high b-values
% this may not work properly causing the correction to work improperly
% Tested for up to b=1000 s/mm^2
bval_to_use = b0var;
% Set threshold to how much b-value may vary from previously set b-value
b_thr = 65;


%%% Check path
% Check whether nifti reading function is found
nifti_path = which('nifti');
if isempty(nifti_path)
    % Error - 'nifti.m' function not found
%     msgbox(sprintf('Nifti reading function ''load_untouch_nii.m'' not found.\n Quitting...'), '', 'error');
    msgbox(sprintf('Nifti reading function ''nifti.m'' not found.\nPlease ensure you have the niftimatlib in your Matlab path. It can be downloaded here:\n''http://sourceforge.net/projects/niftilib/files/niftimatlib/niftimatlib-1.2/''\nQuitting\n'), '', 'error');
    return
end
% Check whether brain mask function is found
mask_path = which('drift_brainmask');
if isempty(mask_path)
    % Error - 'drift_brainmask.m' function not found
    msgbox('Mask function ''drift_brainmask.m'' not found.\n Quitting...', '', 'error');
    return
end
% Check whether nifti saving function is found
save_path = which('SaveAsNifTI');
if isempty(save_path)
    % Error - 'SaveAsNifTI.m' function not found
%     msgbox('Nifti saving function ''save_untouch_nii.m'' not found.\n Quitting...', '', 'error');
    msgbox('Nifti saving function ''SaveAsNifTI.m'' not found. Quitting.', '', 'error');
    return
end


or_pwd = pwd;
if ~exist('file_in', 'var') || ~exist('grad_info_file', 'var') || ...
        ~exist(file_in, 'file') || ~exist(grad_info_file, 'file')
    % Let user select nifti file
    [filename, pathname] = uigetfile({'*.nii;*.nii.gz','Nifti files (*.nii/*.nii.gz)'}...
            ,'Select Nifti file of the diffusion weighted data ...');pause(0.01)
    file_in = [pathname filesep filename];
    if isempty(filename) || ~exist(file_in, 'file')
        % Error
        msgbox('No input image selected. Quitting.', '', 'error');
        return
    end
    cd(pathname);
    % if gzipped, modify base output name
    is_gzipped = false;
    if strcmp(file_in(end-2:end), '.gz')
        is_gzipped = true;
        filename = filename(1:end-3);
    end

    % Let user select gradient info file (bvals, bvecs, or b-matrix)
    [filename_g, pathname_g] = uigetfile({'*','Text files (*.txt/*.bvec/*.bval/*.b)'}...
        ,'Select text file of the diffusion gradients or B-matrix ...');pause(0.01)
    grad_info_file = [pathname_g filesep filename_g];
    if isempty(filename_g) || ~exist(grad_info_file, 'file')
        % Error
        msgbox('No gradient info file selected. Quitting.', '', 'error');
        return
    end
    clear filename_g pathname_g
        
else
    % if gzipped, modify base output name
    is_gzipped = false;
    if strcmp(file_in(end-2:end), '.gz')
        is_gzipped = true;
    end    
end

if ~exist('file_out', 'var')
    % Let user select output file
    if is_gzipped
        [pathname filename] = fileparts(file_in(1:end-3));
        def_name = [filename '_drift_corr.nii'];
        def_name = [def_name '.gz'];
    else
        [pathname filename] = fileparts(file_in);
        def_name = [filename '_drift_corr.nii'];
    end
    [filename_o, pathname_o] = uiputfile({'*.nii;*.nii.gz','Nifti files (*.nii/*.nii.gz)'}, ...
        'Select filename for output file...', def_name);
    cd(or_pwd);
    file_out = [pathname_o filesep filename_o];
    if ~filename_o
        % If user exitted here, define default name as output
        if isempty(pathname)
            file_out = [pwd filesep def_name];
        else
            file_out = [pathname filesep def_name];
        end
    end
    clear filename pathname filename_o pathname_o def_name
end


% Load gradient info
grad_info = load(grad_info_file);
% Transpose if needed
if size(grad_info,1)<size(grad_info,2)
    grad_info = grad_info';
end

if size(grad_info,2)==1
    % Extract which images were b=0-images from b-values (e.g., FSL format)
    b_to_use = find(abs(grad_info-bval_to_use)<b_thr);
elseif size(grad_info,2)==3
    if bval_to_use==0
        % Get vector length for each entry if gradient info is given - not compatible with FSL format
        bvec_length = sum(grad_info.^2,2);
        % Extract which images were b=0-images - they have null vector length
        b_to_use = find(bvec_length<=b_thr);
    else
        % Error
        msgbox('Drift estimation on non-zero b-values not allowed with only gradient direction information option. Quitting.', '', 'error');
        return
    end
elseif size(grad_info,2)==4
    % Get vector length for each entry if MRtrix style info is given
    bvec_length = sum(grad_info(:,1:3).^2,2);
    % Extract which images were b=0-images - they have null vector length
    b_to_use = find(bvec_length<=b_thr);
elseif size(grad_info,2)==6
    % Get b-value if b-matrix is given
    bvals = sum(grad_info(:,[1 4 6]),2);
    % Extract which images were b=0-images
    b_to_use = find(abs(bvals-bval_to_use)<=b_thr);
end

if b_to_use(end) < length(grad_info)
    fprintf('Warning: the null images did not cover the whole diffusion image series\n')
elseif (b_to_use(end)-b_to_use(end-1))*length(b_to_use) < length(grad_info)-(b_to_use(end)-b_to_use(end-1))
    fprintf('Not enough coverage of null images, drifting correction abort, DriftCo Aborting...\n')
    return
end

clear grad_info_file bvec_length bvals

% Get raw data
if is_gzipped
    % gunzip and change filename for reading
    gunzip(file_in); pause(0.5);
    file_in = file_in(1:end-3);
end

% Load nifti
DWI_nii = nifti(file_in);
% DWI_nii = load_untouch_nii(file_in);

% Get number of images
nr_ims = size(DWI_nii.dat,4);
% nr_ims = size(DWI_nii.img,4);

% Check if gradient information has the same number of entries as the input
% DWI nifti
if size(grad_info,1) ~= nr_ims
    msgbox('Gradient information does not match input file. Stopping...','','error')
    return
end
clear grad_info

% Convert data to cell per DWI
raw = cell(nr_ims,1);
for d=1:size(DWI_nii.dat,4)
    raw{d} = DWI_nii.dat(:,:,:,d);
end

% Get all selected images
ims_to_use = raw(b_to_use);

% Get mask for each image
% Set masking parameters
mask_p1 = 0.8; mask_p2 = 5;
% Set erosion kernel
a=3; se = zeros(a,a,a);
se((a+1)/2,(a+1)/2,(a+1)/2)=1;
se = smooth3(se,'gaussian',[a a a],1);
se = se>=se((a+1)/2,(a+1)/2,end);
% Get mask and erode once for each image
mask = cell(length(b_to_use),1);
for i=1:length(b_to_use)
    mask{i} = drift_brainmask(ims_to_use{i},mask_p1,mask_p2);
    mask{i} = imerode(mask{i}, se);
end
clear mask_p* a se i

intsall = zeros(nr_ims,1);
j=0;
for i=1:nr_ims
    if intersect(i,b_to_use)
        j=j+1;
    end
    intsall(i) = mean(raw{i}(mask{j}));
end

% Get mean intensities of each within the mask
ints = zeros(size(b_to_use));
n = length(b_to_use);
x = 1:nr_ims;
for i=1:length(b_to_use)
    ints(i) = mean(ims_to_use{i}(mask{i}));
end

% Check number of datapoints vs number of parameters to fit
if n < 2
    fprintf('Not enough datapoints found (%d) at this b-value (%.1f) to do signal drift correction\n', n, bval_to_use);
    return
end
if strcmpi(drift_method(1), 'l')
    if n < 4
        fprintf('Warning: Only %d datapoints found at this b-value (%.1f)\nSignal drift correction might be unreliable\n', n, bval_to_use);
    end
else
    if n < 3
        fprintf('Not enough datapoints found (%d) at this b-value (%.1f) to do quadratic correction\nConsider using a linear correction\n', n, bval_to_use);
        return
    end
    if n < 6
        fprintf('Warning: Only %d datapoints found at this b-value (%.1f)\nQuadratic correction might be unreliable\nConsider using a linear correction\n', n, bval_to_use);
    end
end

%%% Do fit for correction
w_set = warning('off', 'all');

% Do linear fit
drift_fit_l = fit(b_to_use, ints, 'a*x+b');
corr_l=x.*drift_fit_l.a+drift_fit_l.b;
% Calculate sum squared residuals
res_l = sum((ints'-corr_l(b_to_use)).^2);
% Calculate Akaike's information criteria (AIC)
% (Or small-sample corrected version if required)
K = 2; % Number of datapoints in linear model (disregarding the optional error term)
AIC_l = n*log(res_l/n) + 2*K;
if n/K < 40
    % Use small sample-size bias-correction version 
    AIC_l = n*log(res_l/n) + 2*K + (2*K*(K+1))/(n-K-1);
end

% Do quadratic correction
drift_fit_q = fit(b_to_use, ints, 'a*x^2+b*x+c');
corr_q=(x.^2.*drift_fit_q.a) + x.*drift_fit_q.b + drift_fit_q.c;
% Calculate sum squared residuals
res_q = sum((ints'-corr_q(b_to_use)).^2);
% Calculate Akaike's information criteria (AIC)
% (Or small-sample corrected version if required)
K=3; % Number of datapoints in quadratic model (disregarding the optional error term)
AIC_q = n*log(res_q/n) + 2*K;
if n/K < 40
    % Use bias-corrected version
    AIC_q = n*log(res_q/n) + 2*K + (2*K*(K+1))/(n-K-1);
end

if strcmpi(drift_method(1), 'g')
% Do guassian3 correction
drift_fit_g = fit(b_to_use, ints, 'Gauss3');
corr_g=feval(drift_fit_g,x);
% Calculate sum squared residuals
res_g = sum((ints'-corr_g(b_to_use)).^2);
% Calculate Akaike's information criteria (AIC)
% (Or small-sample corrected version if required)
K=9; % Number of datapoints in quadratic model (disregarding the optional error term)
AIC_g = n*log(res_g/n) + 2*K;
if n/K < 40
    % Use bias-corrected version
    AIC_g = n*log(res_g/n) + 2*K + (2*K*(K+1))/(n-K-1);
end
end

if strcmpi(drift_method(1), 'm')
% Do smoothingspline correction
    for i = 2:length(b_to_use)

        drift_fit_ss=fit([b_to_use(1) b_to_use(i)]', [ints(1) ints(i)]', 'a*x+b');

        for j = b_to_use(i-1)+1:b_to_use(i)
            corr_ss(1,j)=j.*drift_fit_ss.a+drift_fit_ss.b;
        end
    end
    
    if b_to_use(end) ~= nr_ims
        for k= j+1:nr_ims
        corr_ss(1,k)=k.*drift_fit_ss.a+drift_fit_ss.b;
        end
    end
    
corr_ss(1)=ints(1);
% Calculate sum squared residuals
res_ss = sum((ints'-corr_ss(b_to_use)).^2);
% Calculate Akaike's information criteria (AIC)
% (Or small-sample corrected version if required)
K=9; % Number of datapoints in quadratic model (disregarding the optional error term)
AIC_ss = n*log(res_ss/n) + 2*K;
if n/K < 40
    % Use bias-corrected version
    AIC_ss = n*log(res_ss/n) + 2*K + (2*K*(K+1))/(n-K-1);
end
end

% Calculate signal drift correction factor
if strcmpi(drift_method(1), 'l')
    drift_fit = drift_fit_l;
    corr_a=corr_l;
    drift_offset = drift_fit.b;
    legend_text = 'Linear fit';
    % As check, compare AIC of linear and quadratic correction
    if AIC_q < AIC_l
        fprintf('\nAIC of quadratic fit is lower than linear (%.2f vs. %.2f).\nConsider changing the correction to quadratic for better signal drift correction.\n', AIC_q, AIC_l);
    end
elseif strcmpi(drift_method(1), 'q')
    % Do quadratic correction
    drift_fit = drift_fit_q;
    corr_a=corr_q;
    drift_offset = drift_fit.c;
    legend_text = 'Quadratic fit';
    % As check, compare AIC of linear and quadratic correction
    if AIC_l < AIC_q
        fprintf('\nAIC of linear is lower than quadratic (%.2f vs. %.2f).\nYou could consider changing the correction for more stable signal drift correction.\n', AIC_l, AIC_q);
    end
elseif strcmpi(drift_method(1), 'g')
    % Do gaussian 3
    drift_fit = drift_fit_g;
    corr_a=corr_g;
    drift_offset = corr_a(1);
    legend_text = 'Gaussian-3 fit';
    % As check, compare AIC of linear and quadratic correction
%     if AIC_l < AIC_q
%         fprintf('\nAIC of linear is lower than quadratic (%.2f vs. %.2f).\nYou could consider changing the correction for more stable signal drift correction.\n', AIC_l, AIC_q);
%     end
elseif strcmpi(drift_method(1), 'm')
    % Do gaussian 3
    drift_fit = drift_fit_ss;
    corr_a=corr_ss;
    drift_offset = corr_a(1);
    legend_text = 'linearinterp fit';
    % As check, compare AIC of linear and quadratic correction
%     if AIC_l < AIC_q
%         fprintf('\nAIC of linear is lower than quadratic (%.2f vs. %.2f).\nYou could consider changing the correction for more stable signal drift correction.\n', AIC_l, AIC_q);
%     end
end

warning(w_set);
clear drift_fit_* corr_l corr_q res_l res_q n K AIC_* 
decr_prc = (1-corr_a(nr_ims)/corr_a(1))*100;
% Set normalisation value (default is normalisation to fitted offset)
% Can be set to 100 for normalisation to 100, e.g., for harmonisation
% across multiple datasets
norm_val = drift_offset;
% Get correction factor for each image volume
corr_fac = norm_val./corr_a;


% Apply correction to each volume
DWI_corr = cell(size(raw));
for d=1:nr_ims
    DWI_corr{d} = raw{d}*corr_fac(d);
end
clear raw d corr_fac drift_fit

% Get mean b=0-intensities from corrected data
mean_corr_int = double(zeros(length(b_to_use),1));
for i=1:length(b_to_use)
    mean_corr_int(i) = double(mean(DWI_corr{b_to_use(i)}(mask{i})));
end

% Get mean intensities from corrected data
mean_intsall = zeros(nr_ims,1);
j=0;
for i=1:nr_ims
    if intersect(i,b_to_use)
        j=j+1;
    end
    mean_intsall(i) = mean(DWI_corr{i}(mask{j}));
end

% Convert data back to matrix form
DWI_im = repmat(DWI_corr{1},[1 1 1 length(DWI_corr)]);
for d=1:length(DWI_corr)
    DWI_im(:,:,:,d) = DWI_corr{d};
end
clear DWI_corr d i mask

% Save to file
if ~isempty(file_out)
    SaveAsNIfTI(DWI_im, DWI_nii, file_out)
%     DWI_nii.img=DWI_im;
%     save_untouch_nii(DWI_nii,file_out)
end
clear DWI_im DWI_nii

if is_gzipped
    % Delete uncompressed file again
    delete(file_in);
end

if show_intensities
    % Plot correction: Plot raw intensities of B0
    figure, plot(b_to_use, norm_val*ints/drift_offset, 'r.', 'MarkerSize', 10)
    % Add corrected intensities and the fit
    hold on; plot(b_to_use, mean_corr_int, 'b.', 'MarkerSize', 10)
    plot(b_to_use, norm_val*ints/drift_offset, 'b-');
    % Add dashed line at 100%
    plot([-1 nr_ims+2], [norm_val norm_val], 'k--'); xlim([0 nr_ims+1]);
    xlabel('DWI'); ylabel('Signal intensity')
    legend('Uncorrected', 'Corrected', legend_text, 'Location','NorthWest')
    fprintf('There is an estimated %.1f%% signal loss from first to last image\n', decr_prc);
    export_fig('Drifting_Correction_B0only','-transparent','-r120')
end


if show_intensities
    % Plot correction: Plot raw intensities
    figure, plot(b_to_use, ints, 'r.', 'MarkerSize', 10)
    hold on; plot(x, intsall, 'r-');
    % Add corrected intensities and the fit
    hold on; plot(b_to_use, mean_corr_int, 'b.', 'MarkerSize', 10)
%     plot(norm_val*corr_a/drift_offset, 'r--');
    plot(x, mean_intsall, 'b-')
    % Add dashed line at 100%
    plot([-1 nr_ims+2], [norm_val norm_val], 'k--'); xlim([0 nr_ims+1]);
    xlabel('DWI'); ylabel('Signal intensity')
    legend('Uncorrected B0', 'Uncorrected Int', 'Corrected B0', 'Corrected Int', 'Location','SouthWest')
    export_fig('Drifting_Correction_allData','-transparent','-r120')
end

% End of function correct_signal_drift.m
