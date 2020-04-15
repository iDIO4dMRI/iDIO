function SaveAsNIfTI(data, target, output)

% function SaveAsNIfTI(data, nifti, output)
%
% Input:
%
% data: the data array to be saved to disk
%
% target: the NIfTI object specifying the target volume specification
%
% output: the filename for the output NIfTI file
%

% following the example in
% http://niftilib.sourceforge.net/mat_api_html/README.txt
%
% author: Gary Hui Zhang (gary.zhang@ucl.ac.uk)
% Modified: Sjoerd Vos (s.vos@ucl.ac.uk)
%  to: allow gzipped output
%

% SV: Check if output is requested to be gzipped ...
is_gzipped = false;
if strcmp(output(end-2:end), '.gz')
    % ... if so, enable saving to uncompressed nifti first
    is_gzipped = true;
    output = output(1:end-3);
end

dat = file_array;
dat.fname = output;
if isfield(target, 'dim')
    dat.dim = target.dim;
elseif isfield(target, 'dat') && isfield(target.dat, 'dim')
    dat.dim = target.dat.dim;
else
    dat.dim = size(data);
end
dat.dtype = 'FLOAT64-LE';
dat.offset = ceil(348/8)*8;

N = nifti;
N.dat = dat;
N.mat = target.mat;
N.mat_intent = target.mat_intent;
N.mat0 = target.mat0;
N.mat0_intent = target.mat0_intent;

create(N);

N.dat(:,:,:,:) = data;

% SV: and then finally gzip output and remove uncompressed nifti if necessary
if is_gzipped
    gzip(output);
    delete(output);
end

