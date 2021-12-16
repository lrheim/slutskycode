function fr = firingRate(spktimes, varargin)

% wrapper for firing rate functions. calculates firing rate based on spike
% times and smoothes result by a moving average (MA) or Gaussian kernel
% (GK) impleneted by multiple-pass MA. Default is to calculate firing rate
% in sliding 1-min windows of 20 s steps (Miyawaki et al., Sci. Rep.,
% 2019). In practice this is done by setting binsize to 60 s and smoothing
% w/ moving average of 3 points.
%
% INPUT
%   spktimes    a cell array of vectors. each vector (unit / tetrode)
%               contains the timestamps of spikes. for example
%               {spikes.times{1:4}}
%   basepath    recording session path {pwd}
%   graphics    plot figure {1}.
%   saveFig     save figure {1}.
%   saveVar     logical / char. save variable {true}. if char than variable
%               will be named saveVar.mat
%   winCalc     time window for calculation {[1 Inf]}. specified in s.
%   binsize     size bins {60}. specified in s.
%   metBL       calculate baseline as 'max' or {'avg'}.
%   winBL       window to calculate baseline FR {[1 Inf]}.
%               specified in s.
%   select      cell array with strings expressing method to select units.
%               'thr' - units with fr > 0.05 during baseline
%               'stable' - units with std of fr < avg of fr during
%               baseline. default = none.
%   smet        method for smoothing firing rate: moving average (MA) or
%               Gaussian kernel (GK) impleneted by multiple-pass MA. {[]}.
%
% OUTPUT
% fr            struct with fields strd, norm, bins, binsize,
%               normMethod, normWin
%
% TO DO LIST
%               adjust winCalc to matrix
%
% 26 feb 19 LH.
% 21 nov 19 LH  added active periods and mFR accordingly
% 09 may 20 LH  fixed c2r issues with calcFR
% 03 feb 21 LH  added states

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
validate_win = @(win) assert(isnumeric(win) && length(win) == 2,...
    'time window must be in the format [start end]');

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'binsize', 60, @isscalar);
addOptional(p, 'winCalc', [1 Inf], validate_win);
addOptional(p, 'winBL', [], validate_win);
addOptional(p, 'metBL', 'avg', @ischar);
addOptional(p, 'select', {''}, @iscell);
addOptional(p, 'smet', 'none', @ischar);
addOptional(p, 'graphics', true, @islogical);
addOptional(p, 'saveFig', true, @islogical);
addOptional(p, 'saveVar', true);

parse(p, varargin{:})
basepath = p.Results.basepath;
binsize = p.Results.binsize;
winCalc = p.Results.winCalc;
winBL = p.Results.winBL;
metBL = p.Results.metBL;
select = p.Results.select;
smet = p.Results.smet;
graphics = p.Results.graphics;
saveFig = p.Results.saveFig;
saveVar = p.Results.saveVar;

% validate window
if winCalc(end) == Inf
    winCalc(end) = max(vertcat(spktimes{:}));
end

smfactor = 7;    % smooth factor
nunits = length(spktimes);
[~, basename] = fileparts(basepath);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calc firing rate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% calc fr across entire session
[fr.strd, ~, fr.tstamps] = times2rate(spktimes, 'binsize', binsize,...
    'winCalc', winCalc, 'c2r', true);

% calc fr according to states. note states, binsize, and spktimes must be
% the same units (typically sec)
if exist(fullfile(basepath, [basename '.AccuSleep_states.mat']))
    load(fullfile(basepath, [basename '.AccuSleep_states.mat']), 'ss')    
    fr.states.stateNames = ss.labelNames;
    nstates = length(ss.stateEpochs);
  
    % apply threshold for epoch length to calc states
    fr.states.epochThr = [10, 10, 0, 10, 0, 0];
    if length(fr.states.epochThr) == 1
        fr.states.epochThr = repmat(fr.states.epochThr, 6, 1);
    elseif length(fr.states.epochThr) ~= nstates - 1
        warning('thrBin length is different than the number of states')
    end

    % limit stateEpochs according to epoch length and fit to winCalc
    for istate = 1 : nstates - 1
        epochIdx = ss.stateEpochs{istate}(:, 2) < winCalc(2) &...
            ss.stateEpochs{istate}(:, 1) > winCalc(1);
        thrIdx =  ss.epLen{istate} > fr.states.epochThr(istate);
        ss.stateEpochs{istate} = ss.stateEpochs{istate}(thrIdx & epochIdx, :);
         if ~isempty(ss.stateEpochs{istate})
            [fr.states.fr{istate}, fr.states.binedges, fr.states.tstamps{istate}, fr.states.binidx] =...
                times2rate(spktimes, 'binsize', binsize, 'winCalc', ss.stateEpochs{istate}, 'c2r', true);
        end
    end
        
    % buzsaki format
elseif exist(fullfile(basepath, [basename '.SleepState.states.mat']))
    load(fullfile(basepath, [basename '.SleepState.states.mat']))
    
    fr.states.statenames = {'WAKE', 'NREM', 'REM'};
    ss = struct2cell(SleepState.ints);
    nstates = length(ss);
    for i = 1 : nstates
        statetimes = ss{i};
        [fr.states.fr{i}, fr.states.binedges, fr.states.tstamps{i}, fr.states.binidx{i}] =...
            times2rate(spktimes, 'binsize', binsize, 'winCalc', statetimes, 'c2r', true);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% modulate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% smooth
switch smet
    case 'MA'
        fr.strd = movmean(fr.strd, smfactor, 2);
    case 'GK'
        gk = gausswin(smfactor);
        gk = gk / sum(gk);
        for i = 1 : nunits
            fr.strd(i, :) = conv(fr.strd(i, :), gk, 'same');
        end
end

% normalize firing rate
if isempty(winBL)
    winBL = [1 size(fr.strd, 2)];
else
    winBL = winBL / binsize;
    if winBL(1) < 1
        winBL(1) = 1;
    end
    if winBL(2) == Inf
        winBL(2) = size(fr.strd, 2);
    end
end
fr.norm = fr.strd ./ mean(fr.strd(:, winBL(1) : winBL(2)), 2);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% apply criterions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

bl = mean(fr.strd(:, winBL(1) : winBL(2)));

% select units who fired above thr
if any(strcmp(select, 'thr'))
    ithr = bl > 0.05;
else
    ithr = ones(nunits, 1);
end
% select units with low variability
if any(strcmp(select, 'stable'))
    bl_std = std(fr(:, win(1) : win(2)), [], 2);
    istable = bl_std < bl;
else
    istable = ones(nunits, 1);
end
idx = istable & ithr;

% add params
fr.winBL = winBL;
fr.binsize = binsize;
fr.mfr = mean(fr.strd, 2);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if saveVar
    if ischar(saveVar)
        save([basepath, filesep, basename, '.' saveVar '.mat'], 'fr')
    else
        save([basepath, filesep, basename, '.fr.mat'], 'fr')
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if graphics
    plot_FRtime_session('basepath', basepath)
end

return

% EOF

