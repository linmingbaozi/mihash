function opts = get_opts(opts, dataset, nbits, varargin)
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
% additional information.
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
% Sets up data stream settings.
% The data stream constitutes "trainingPoints" x "epochs" training instances, i.e., the
% online learning is continued until "trainingPoints" x "epochs" examples are processed
% where "trainingPoints" should be smaller than the available training data.  
% In this data stream, "ntests" checkpoints are randomly placed in which the 
% performance, as measured by the "metric" value, is evaluated. This can be used
% to plot performance vs. training instances curves. See illustration below.
%
% |----o-------o--------o----o-------o--------| ← Data stream 
% ↑    ↑                ↑                     ↑
% 1 "checkpoint #2"  "checkpoint #4"        "trainingPoints" x "epochs"
%
% (checkpoint #1 is on the 1st iteration)
% 
% REFERENCES
% [1] Fatih Cakir*, Kun He*, Sarah Adel Bargal, Stan Sclaroff (*equal contribution)
%     "MIHash: Online Hashing with Mutual Information", 
%     International Conference on Computer Vision (ICCV) 2017.
%
% INPUTS
% 	dataset - (string) A string denoting the dataset to be used. 
%			   Please add/edit  load_gist.m and load_cnn.m for available
%			   datasets.
% 	nbits   - (int)    Hash code length
% 	
%      numTrain - (int)    The number of training instances to be processed in each
% 			   epoch. Must be smaller than the available training data.
% 	ntrials - (int)	   The number of trials. A trial corresponds to a separate
% 			   experimental run. The performance results then are average
% 			   across different trials. See test.m .
% 	ntests  - (int)    This parameter corresponds to the number of checkpoints
% 			   as illustrated above. This amount of checkpoints is placed
% 			   at random locations in the data stream to evaluate the 
% 			   hash methods performance. Must be [2, "trainingPoints"x"epochs"].
% 			   The performance is evaluated on the first and last 
%			   iteration, at the least.
% 	metric  - (string) Choices are 'prec_kX', 'prec_nX', 'mAP_X' and 'mAP' where
%			   X is an integer. 'prec_k100' evaluates the  precision 
% 			   value of the 100 nearest neighbors (average over the 
% 			   query set). 'prec_n3' evaluates the precision value 
% 			   of neighbors returned within a Hamming radius 3 
% 			   (averaged over the query set). 'mAP_100' evaluates the
% 			   average precision of the 100 nearest neighbors (average
%			   over the query set). 'mAP' evaluates the mean average 
% 			   precision.  
%	epoch 	- (int)    Number of epochs, [1, inf) 			    
% 	prefix 	- (string) Prefix for the results folder title, if empty, the 
% 			   results folder will be prefixes with todays date.
%  randseed - (int)   Random seed for reproducility. 			   
% 	override - (int)   {0, 1}. If override=0, then training and/or testing
% 			   that correspond to the same experiment, is avoided when
% 			   possible. if override=1, then (re-)runs the experiment
% 			   no matter what.
%      showplots - (int)   {0, 1}. If showplots=1, plots the performance curve wrt
% 			   training instances, CPU time and Bit Recomputations. 
% 			   See test.m .
%      localdir - (string) Directory path where the results folder will be created.
% reservoirSize - (int)    The size of the set to be sampled via reservoir sampling 
% 			   from the data stream. The reservoir can be used to 
% 			   compute statistical properties of the stream. For future 
% 			   release purposes.
% updateInterval - (int)   The hash table is updated after each "updateInterval" 
%			   number of training instances is processed.
%	trigger	- (string) Choices are 'mi' or 'fix' (default). The type of trigger 
%	                   used to determine if a hash table update is needed. 
%	                   'mi' means mutual information (see [1] above). If 'fix' 
%	                   is selected, then the hash table is updated at every 
%	                   'updateInterval'.
% 
% OUTPUTS
%	opts	- (struct) struct containing name and values of the inputs, e.g.,
%			   opts.dataset, opts.nbits, ... .

ip = inputParser;

% train/test
ip.addRequired('dataset'    , @isstr);
ip.addRequired('nbits'      , @isscalar);
ip.addParamValue('numTrain' , 20e3        , @isscalar);
ip.addParamValue('ntrials'  , 3           , @isscalar);
ip.addParamValue('ntests'   , 50          , @isscalar);
ip.addParamValue('metric'   , 'mAP'       , @isstr);    % evaluation metric
ip.addParamValue('epoch'    , 1           , @isscalar)

% Reservoir & Trigger Update module
ip.addParamValue('reservoirSize'  , 0    , @isscalar);  % reservoir size
ip.addParamValue('updateInterval' , 100  , @isscalar);  % use with baseline
ip.addParamValue('trigger'        , 'mi' , @isstr);     % update trigger type
ip.addParamValue('miThresh'       , 0    , @isscalar);  % for trigger=mi

% misc
ip.addParamValue('prefix'    , ''           , @isstr);
ip.addParamValue('randseed'  , 12345        , @isscalar);
ip.addParamValue('override'  , 0            , @isscalar);
ip.addParamValue('showplots' , 0            , @isscalar);
ip.addParamValue('localdir'  , './cachedir' , @isstr);

% parse input
ip.KeepUnmatched = true;
ip.parse(lower(dataset), nbits, varargin{:});
opts = catstruct(ip.Results, opts);  % combine w/ existing opts


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ASSERTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
assert(opts.ntests >= 2, 'ntests should be at least 2 (first & last iter)');
assert(mod(opts.updateInterval, opts.batchSize) == 0, ...
    sprintf('updateInterval should be a multiple of batchSize(%d)', opts.batchSize));
if strcmp(opts.trigger, 'mi')
    assert(opts.reservoirSize>0, 'trigger=mi needs reservoirSize>0');
end

if strcmp(opts.dataset, 'labelme') 
    assert(~strcmpi(opts.methodID, 'OSH')); % OSH is inapplicable on LabelMe 
    opts.unsupervised = 1;
    opts.ftype = 'gist';
else
    % CIFAR and PLACES
    opts.unsupervised = 0;
    opts.ftype = 'cnn';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CONFIGS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% dirs
localdir = opts.localdir;
if isfield(opts, 'methodID') && ~isempty(opts.methodID)
    localdir = fullfile(localdir, opts.methodID);
end
if exist(localdir, 'dir') == 0, mkdir(localdir); end
opts = rmfield(opts, 'localdir');

opts.dirs = [];
opts.dirs.local = localdir;
opts.dirs.data  = fullfile(pwd, '..', 'data');

% set randseed
rng(opts.randseed, 'twister');

% decipher evaluation metric
if ~isempty(strfind(opts.metric, 'prec_k'))
    % eg. prec_k3 is precision at k=3
    opts.prec_k = sscanf(opts.metric(7:end), '%d');
elseif ~isempty(strfind(opts.metric, 'prec_n'))
    % eg. prec_n3 is precision at n=3
    opts.prec_n = sscanf(opts.metric(7:end), '%d');
elseif ~isempty(strfind(opts.metric, 'mAP_'))
    % eg. mAP_1000 is mAP @ top 1000 retrievals
    opts.mAP = sscanf(opts.metric(5:end), '%d');
else 
    % default: mAP
    assert(strcmp(opts.metric, 'mAP'), ['unknown opts.metric: ' opts.metric]);
end


% --------------------------------------------
% identifier string for the current experiment
% NOTE: opts.identifier is already initialized with method-specific params
opts.identifier = sprintf('%s-%s-%d-%s', opts.dataset, opts.ftype, ...
    opts.nbits, opts.identifier);
idr = opts.identifier;

% handle reservoir
if opts.reservoirSize > 0
    idr = sprintf('%s-RS%d', idr, opts.reservoirSize);
    if opts.updateInterval > 0
        idr = sprintf('%sU%d', idr, opts.updateInterval);
    end
    if strcmp(opts.trigger, 'mi')
        idr = sprintf('%s-MI%g', idr, opts.miThresh);
    else
        assert(strcmp(opts.trigger, 'fix'), ...
            'Only [mi] & [fix] are supported for opts.trigger');
        idr = sprintf('%s-FIX', idr);
    end
else
    % no reservoir (baseline): must use updateInterval
    assert(opts.updateInterval > 0);
    idr = sprintf('%s-U%d', idr, opts.updateInterval);
end
if isempty(opts.prefix)
    prefix = sprintf('%s',datetime('today','Format','yyyyMMdd')); 
end;
opts.identifier = [prefix '-' idr];

% set expdir
exp_base = sprintf('%s/%s', opts.dirs.local, opts.identifier);
opts.dirs.exp = sprintf('%s/%gpts_%gepochs_%dtests', exp_base, ...
    opts.numTrain, opts.epoch, opts.ntests);
if ~exist(exp_base, 'dir'), mkdir(exp_base); end
if ~exist(opts.dirs.exp, 'dir'),
    logInfo(['creating: ' opts.dirs.exp]);
    mkdir(opts.dirs.exp);
end

% FINISHED
logInfo('identifier: %s', opts.identifier);
disp(opts);
end
