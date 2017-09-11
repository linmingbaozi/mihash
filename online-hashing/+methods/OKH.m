classdef OKH
% Copyright (c) 2017, Fatih Cakir, Kun He, Saral Adel Bargal, Stan Sclaroff 
% All rights reserved.
% 
% If used for academic purposes please cite the below paper:
%
% "MIHash: Online Hashing with Mutual Information", 
% Fatih Cakir*, Kun He*, Sarah Adel Bargal, Stan Sclaroff
% (* equal contribution)
% International Conference on Computer Vision (ICCV) 2017
% 
% Usage of code from authors not listed above might be subject
% to different licensing. Please check with the corresponding authors for
% additioanl information.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
% 
% 1. Redistributions of source code must retain the above copyright notice, this
%    list of conditions and the following disclaimer.
% 2. Redistributions in binary form must reproduce the above copyright notice,
%    this list of conditions and the following disclaimer in the documentation
%    and/or other materials provided with the distribution.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
% ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
% WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
% ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
% (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
% ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
% SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
% 
% The views and conclusions contained in the software and documentation are those
% of the authors and should not be interpreted as representing official policies,
% either expressed or implied, of the FreeBSD Project.
%
%------------------------------------------------------------------------------
% Training routine for OKH method, see demo_okh.m .
%
% INPUTS
% 	Xtrain - (float) n x d matrix where n is number of points 
%       	         and d is the dimensionality 
%
% 	Ytrain - (int)   n x l matrix containing labels, for unsupervised datasets
% 			 might be empty, e.g., LabelMe.
%     thr_dist - (int)   For unlabelled datasets, corresponds to the distance 
%		         value to be used in determining whether two data instance
% 		         are neighbors. If their distance is smaller, then they are
% 		         considered neighbors.
%	       	         Given the standard setup, this threshold value
%		         is hard-wired to be compute from the 5th percentile 
% 		         distance value obtain through 2,000 training instance.
% 			 see load_gist.m . 
% 	prefix - (string) Prefix of the "checkpoint" files.
%   test_iters - (int)   A vector specifiying the checkpoints, see train.m .
%   trialNo    - (int)   Trial ID
%	opts   - (struct)Parameter structure.
%
% OUTPUTS
%  train_time  - (float) elapsed time in learning the hash mapping
%  update_time - (float) elapsed time in updating the hash table
%  res_time    - (float) elapsed time in maintaing the reservoir set
%  ht_updates  - (int)   total number of hash table updates performed
%  bit_computed_all - (int) total number of bit recomputations, see update_hash_table.m
% 
% NOTES
% 	W is d x b where d is the dimensionality 
%            and b is the bit length / # hash functions
%
% 	If number_iterations is 1000, this means 2000 points will be processed, 
% 	data arrives in pairs

properties
    KX
    para
end

methods
    function [W, R, obj] = init(obj, R, X, Y, opts)
        % do kernel mapping to Xtrain
        % KX: each COLUMN is a kernel-mapped training example
        assert(size(X, 1) >= 4000);

        % sample support samples (300) from the FIRST HALF of training set
        nhalf = floor(size(X, 1)/2);
        ind = randperm(nhalf, 300);
        Xanchor = X(ind, :);
        logInfo('Randomly selected 300 anchor points');

        % estimate sigma for Gaussian kernel using samples from the SECOND HALF
        ind = randperm(nhalf, 2000);
        Xval = X(nhalf+ind, :);
        Kval = sqdist(Xval', Xanchor');
        sigma = mean(mean(Kval, 2));
        logInfo('Estimated sigma = %g', sigma);
        clear Xval Kval

        % kernel mapping the whole set
        KX = exp(-0.5*sqdist(X', Xanchor')/sigma^2)';
        KX = [KX; ones(1,size(KX,2))];

        para.c      = opts.c; %0.1;
        para.alpha  = opts.alpha; %0.2;
        para.anchor = Xanchor;

        % LSH init
        d = size(KX, 1);
        W = randn(d, opts.nbits);
        W = W ./ repmat(diag(sqrt(W'*W))',d,1);
    end


    function [W, ind] = train1batch(obj, W, R, X, Y, I, t, opts)
        % TODO affinity
        if ~opts.unsupervised
            idx_i = Y(2*t-1, :);
            idx_j = Y(2*t, :);
            s = 2*(idx_i==idx_j)-1;
        else
            idx_i = []; 
            idx_j = [];
            D = pdist([X(2*iter-1,:); X(2*iter,:)], 'euclidean');
            s = 2*(D <= thr_dist) - 1;
        end

        xi = obj.KX(:, 2*iter-1);
        xj = obj.KX(:, 2*iter);

        % hash function update
        W = methods.OKHlearn(xi, xj, s, W, obj.para);
    end

end % methods

end % classdef
