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
%   saveVar     logical / char. save variable {true}. if char than variable
%               will be named saveVar.mat
%   winCalc     time window for calculation {[1 Inf]}. specified in s.
%   binsize     size bins {60}. must be the same units as spktimes (e.g.
%               [s])
%   winBL       window to calculate baseline FR {[1 Inf]}.
%               specified in s.
%   smet        method for smoothing firing rate: moving average (MA) or
%               Gaussian kernel (GK) impleneted by multiple-pass MA. {[]}.
%   forceA      logical. force analysis even if struct file exists {false}
%
% OUTPUT
% fr            struct 
%
% TO DO LIST
%               adjust winCalc to matrix (done)
%               apply params (e.g. gini) to states
%
% 26 feb 19 LH  updates:
% 21 nov 19 LH  added active periods and mFR accordingly
% 09 may 20 LH  fixed c2r issues with calcFR
% 03 feb 21 LH  added states
% 26 dec 21 LH  gini coefficient and fano factor

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
validate_win = @(win) assert(isnumeric(win) && length(win) == 2,...
    'time window must be in the format [start end]');

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'binsize', 60, @isscalar);
addOptional(p, 'winCalc', [0 Inf], validate_win);
addOptional(p, 'winBL', [0 Inf], validate_win);
addOptional(p, 'smet', 'none', @ischar);
addOptional(p, 'graphics', true, @islogical);
addOptional(p, 'saveVar', true);
addOptional(p, 'forceA', true, @islogical);

parse(p, varargin{:})
basepath = p.Results.basepath;
binsize = p.Results.binsize;
winCalc = p.Results.winCalc;
winBL = p.Results.winBL;
smet = p.Results.smet;
graphics = p.Results.graphics;
saveVar = p.Results.saveVar;
forceA = p.Results.forceA;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% params
smfactor = 7;    % smooth factor
nunits = length(spktimes);

% filenames
[~, basename] = fileparts(basepath);
if ischar(saveVar)
    frFile = [basepath, filesep, basename, '.' saveVar '.mat'];
else
    frFile = [basepath, filesep, basename, '.fr.mat'];
end
asFile = fullfile(basepath, [basename '.AccuSleep_states.mat']);

% check if already analyzed
if exist(frFile, 'file') && ~forceA
    load(frFile)
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calc firing rate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% calc fr across entire session
[fr.strd, ~, fr.tstamps] = times2rate(spktimes, 'binsize', binsize,...
    'winCalc', winCalc, 'c2r', true);

% calc fr according to states. note states, binsize, and spktimes must be
% the same units (typically sec)
if exist(asFile)
    load(asFile, 'ss')    
    fr.states.stateNames = ss.labelNames;
    nstates = length(ss.stateEpochs);

    % fit stateEpochs to winCalc and count spikes in states
    for istate = 1 : nstates
        if isempty(ss.stateEpochs{istate})
            fr.states.fr{istate} = zeros(nunits, 1);
            fr.states.tstamps{istate} = 0;
            continue
        end
        epochIdx = ss.stateEpochs{istate}(:, 2) < winCalc(2) &...
            ss.stateEpochs{istate}(:, 1) > winCalc(1);
        stateEpochs = ss.stateEpochs{istate}(epochIdx, :);
         if ~isempty(ss.stateEpochs{istate})
            [fr.states.fr{istate}, fr.states.binedges, fr.states.tstamps{istate}, fr.states.binidx] =...
                times2rate(spktimes, 'binsize', binsize, 'winCalc', stateEpochs, 'c2r', true);
        end
    end
    
    % gain factor compared to state 1 (AWAKE)
    for istate = 1 : nstates
        mat1 = fr.states.fr{1};
        mat2 = fr.states.fr{istate};
        fr.states.gain(istate, :) = (mean(mat2, 2, 'omitnan') -...
            mean(mat1, 2, 'omitnan')) ./ max([mat1, mat2], [], 2) * 100;
    end
    
    % normalized ratio (mizuseki, cell rep., 2008). organized as a 3d mat
    % of all pairs.
    for istate = 1 : nstates
        for istate2 = 1 : nstates
        mat1 = mean(fr.states.fr{istate}, 2, 'omitnan');
        mat2 = mean(fr.states.fr{istate2}, 2, 'omitnan');
        fr.states.ratio(istate, istate2, :) =...
            (mat1 - mat2) ./ (mat1 + mat2);
        end
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
bl_idx = fr.tstamps > winBL(1) & fr.tstamps < winBL(2);
bl_fr = fr.strd(:, bl_idx);
fr.mfr = mean(bl_fr, 2, 'omitnan');
fr.mfr_std = std(bl_fr, [], 2, 'omitnan');
fr.norm = fr.strd ./ fr.mfr;

% apply criterions
bl_thr = 0.01;   % [Hz]
fr.bl_thr = fr.mfr > bl_thr;
fr.stable = fr.mfr_std < fr.mfr;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% more params 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Fano factor: variability in fr relative to mfr
fr.fanoFactor = var(bl_fr, [], 2) ./ mean(bl_fr, 2);

% Gini coefficient. calculated per unit (as in CE); the gini describes the
% inequality of fr bins throughout time. calculated across the popultion
% (mizuseki, cell rep., 2008), the gini describes the degree to which high
% mfr units accounted for most the spikes recorded
cum_fr = cumsum(sort(bl_fr, 2), 2);
cum_fr_norm = cum_fr ./ max(cum_fr, [], 2);
for iunit = 1 : nunits
    fr.gini_unit(iunit) = gini(ones(1, size(bl_fr, 2)), cum_fr_norm(iunit, :));
end
fr.gini_pop = gini(ones(1, size(bl_fr, 1)),...
    cumsum(sort(fr.mfr)) / max(cumsum(fr.mfr)));

% AR(1): auto-regressive
% plot(fr.strd(iunit, 1 : end-1), fr.strd(iunit, 2 : end), '*')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% organize and save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% struct
fr.info.runtime = datetime(now, 'ConvertFrom', 'datenum');
fr.info.winBL = winBL;
fr.info.winCalc = winCalc;
fr.info.binsize = binsize;
fr.info.smoothMethod = smet;
fr.info.bl_thr = bl_thr;

% save
if saveVar
    save(frFile, 'fr')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if graphics
    plot_FRtime_session('basepath', basepath)
end

return

% EOF
