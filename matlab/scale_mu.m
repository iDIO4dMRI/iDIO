function scale_mu(Matrix_path, mu_path, savepath)
% multify the SIFT2weigted matrix and the mu metric
M=load(Matrix_path);
mu=load(mu_path);
ScaleM=M.*mu;
csvwrite(savepath, ScaleM);