function ripp = getRipples(varargin)

% Detects ripples from lfp: rectifies (squares) the signal, applies a
% moving average, standardizes, finds crossings of a threshold
%(in z-scores) and converts them to epochs by applying duration criterions.
% Alas, discards ripples with a low peak power. After detection, calculates
% various stats and plots a summary. based in part on
% bz_FindRipples but.
% 
% INPUT:
%   basepath        path to recording {pwd}
%   sig             numeric vec of lfp data. if empty will be loaded from
%                   basename.lfp according to rippCh.  
%   emg             numeric of emg data. must be the same sampling
%                   frequency as sig. can be acc.mag. used for
%                   normalization and exclusion of artifacts
%   fs          	numeric. sampling frequency of lfp file / data. 
%                   if empty will be extracted from session info (ce
%                   format)
%   rippCh          numeric vec. channels to load and average from lfp
%                   file {1}. if empty will be selected best on the ratio
%                   of mean to median within the passband. 
%   emgCh           numeric vec. emg channel in basename.lfp file. 
%   recWin          numeric 2 element vector. time to analyse in recording
%                   [s]. start of recording is marked by 0. {[0 Inf]}
%   graphics        logical. plot graphics {true} or not (false)
%   saveVar         logical. save variables (update spikes and save su)
%   spkFlag         logical. analyze spikes in ripples {true}
%
% OUTPUT:
%   ripp            struct
%
% DEPENDENCIES:
%   binary2epochs
%   lfpFilter
%   Sync (buzcode)
%   SyncMap (buzcode)
%   PlotColorMap (buzcode)
%   bz_getRipSPikes (buzcode)
%
% TO DO LIST:
%   finish graphics (done)
%   stats (done)
%   rate (done)
%   exclusion by emg noise (done)
%   exclusion by spiking activity
%   exlude active periods when normalizing signal (done)
%   allow user to input sig directly instead of loading from binary (done)
%   improve routine to select best ripple channel automatically
%
% 02 dec 21 LH

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'sig', [], @isnumeric);
addOptional(p, 'emg', [], @isnumeric);
addOptional(p, 'recWin', [0 Inf]);
addOptional(p, 'rippCh', 1, @isnumeric);
addOptional(p, 'emgCh', [], @isnumeric);
addOptional(p, 'fs', [], @isnumeric);
addOptional(p, 'graphics', true, @islogical);
addOptional(p, 'saveVar', true, @islogical);
addOptional(p, 'spkFlag', true, @islogical);

parse(p, varargin{:})
basepath    = p.Results.basepath;
sig         = p.Results.sig;
emg         = p.Results.emg;
recWin      = p.Results.recWin;
rippCh      = p.Results.rippCh;
fs          = p.Results.fs;
graphics    = p.Results.graphics;
saveVar     = p.Results.saveVar;
spkFlag     = p.Results.spkFlag;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% files
cd(basepath)
[~, basename] = fileparts(basepath);
ssfile = fullfile(basepath, [basename '.sleep_states.mat']);
sessionfile = fullfile(basepath, [basename, '.session.mat']);
rippfile = fullfile(basepath, [basename, '.ripp.mat']);
clufile = fullfile(basepath, [basename, '.ripp.clu.1']);
resfile = fullfile(basepath, [basename, '.ripp.res.1']);
spikesfile = fullfile(basepath, [basename, '.spikes.cellinfo.mat']);
spktimesfile = fullfile(basepath, [basename, '.spktimes.mat']);

% load session info
if ~exist(sessionfile, 'file')
    session = CE_sessionTemplate(pwd, 'viaGUI', false,...
        'forceDef', false, 'forceL', false, 'saveVar', false);
else
    load(sessionfile)
end

% state configuration
cfg = as_loadConfig([]);
sstates = [1 : 6];  % selected states

spkgrp = session.extracellular.spikeGroups.channels;
spkch = sort([spkgrp{:}]);
nchans = session.extracellular.nChannels;
fsSpks = session.extracellular.sr;
if isempty(fs)
    fs = session.extracellular.srLfp;
end

% detection params
limDur = [20 150, 30];      % min, max, and inter dur limits for ripples [ms]
limDur = limDur / 1000 * fs;
passband = [120 250];
binsizeRate = 60;           % binsize for calculating ripple rate [s]
emgThr = 50;                % exclude ripples that occur when emg > thr

% threshold of stds above sig_amp
dtctMet = 1;        % 1 = TL; 2 = BZ
switch dtctMet
    case 1
        thr = [2.5 3.5];
    case 2
        thr = [1 3];
end

fprintf('\ngetting ripples for %s\n', basename)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isempty(sig)    
    if isempty(rippCh)
        % if rippCh not specified, load 4 hr of data and find ch with best
        % SNR for ripples. note this subrutine occasionally points to the
        % channel with the highest movement artifacts / spikes. it is also
        % very time consuming. better to select manually.
        fprintf('selecting best ripple channel...\n')

        recDur = min([diff(recWin), 4 * 60 * 60]);
        sig = double(bz_LoadBinary([basename, '.lfp'], 'duration', recDur,...
            'frequency', fs, 'nchannels', nchans, 'start', recWin(1),...
            'channels', spkch, 'downsample', 1));
        
        sig_filt = filterLFP(sig, 'fs', fs, 'type', 'butter', 'dataOnly', true,...
            'order', 5, 'passband', passband, 'graphics', false);
        
        pow = fastrms(sig_filt, 15);
        ch_rippPowRatio = mean(pow) ./ median(pow);
        [~, rippCh] = max(ch_rippPowRatio);
    end
    
    % load all data and average across channels
    fprintf('loading lfp data...\n')
    sig = double(bz_LoadBinary([basename, '.lfp'], 'duration', diff(recWin),...
        'frequency', fs, 'nchannels', nchans, 'start', recWin(1),...
        'channels', rippCh, 'downsample', 1));
    if length(rippCh) > 1
        sig = mean(sig, 2);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% prepare signal
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('preparing signal...\n')

% normalize data to ripple power during immobility or NREM. currently note
% used
norm_idx = true(length(sig), 1);   % initialize
if ~isempty(emg)
    norm_idx = emg < prctile(emg, 100 - emgThr);
    
elseif exist(ssfile)    
    load(ssfile, 'ss')    
    nrem_stateIdx = find(strcmp(cfg.names, 'NREM'));
    
    % find nrem indices by upsampling the labels. assumes the binsize
    % (epoch length) of labels is 1 sec.
    nrem_inInt = InIntervals([1 : length(ss.labels)], recWin);
    norm_idx = repelem(ss.labels(nrem_inInt) == nrem_stateIdx, fs);
end

% normalize
% sig_filt = (sig - mean(sig(norm_idx))) / std(sig(norm_idx));

% filter lfp data in ripple band
sig_filt = filterLFP(sig, 'fs', fs, 'type', 'butter', 'dataOnly', true,...
    'order', 5, 'passband', passband, 'graphics', false);

% instantaneous phase and amplitude
h = hilbert(sig_filt);
sig_phase = angle(h);
sig_amp = abs(h);
sig_unwrapped = unwrap(sig_phase);

% instantaneous frequency
tstamps = [1 / fs : 1 / fs : length(sig) / fs];
tstamps = tstamps(:);
dt = diff(tstamps);
t_diff = tstamps(1 : end - 1) + dt / 2;
d0 = diff(medfilt1(sig_unwrapped, 12)) ./ dt;
d1 = interp1(t_diff, d0, tstamps(2 : end - 1, 1));
sig_freq = [d0(1); d1; d0(end)] / (2 * pi);

% -------------------------------------------------------------------------
% detection signal
switch dtctMet
    case 1              % TL detection (smoothed amplitude)
        % smooth amplitude. note TL averages the smoothed amplitude from a few
        % channels.
        % sig_dtct = smoothdata(sig_amp, 'gaussian', round(5 / (1000 / 1250)));       
        sig_dtct = (sig_amp - mean(sig_amp)) / std(sig_amp);
        
    case 2              % BZ detection (nss)
        sig_dtct = sig_filt .^ 2;
        winFilt = ones(11, 1) / 11;
        shift = (length(winFilt) - 1) / 2;
        [sig_dtct, z] = filter(winFilt, 1, sig_dtct);
        sig_dtct = [sig_dtct(shift + 1 : end, :); z(1 : shift, :)];
        sig_dtct = (sig_dtct - mean(sig_dtct)) / std(sig_dtct);
        
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% find ripples
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% find epochs with power > low threshold. correct for durations
epochs = binary2epochs('vec', sig_dtct > thr(1), 'minDur', limDur(1),...
    'maxDur', limDur(2), 'interDur', limDur(3));
nepochs = size(epochs, 1);

% discard ripples that occur during high emg 
if ~isempty(emg)
    for iepoch = 1 : nepochs
        emgRipp(iepoch) = mean(emg(epochs(iepoch, 1) : epochs(iepoch, 2)));
    end
    discard_idx = emgRipp > prctile(emg, emgThr);
    epochs(discard_idx, :) = [];
    emgRipp(discard_idx) = [];
    nepochs = size(epochs, 1);
    fprintf('After emg exclusion: %d events\n', nepochs)
end

% discard ripples with a peak power < high threshold
clear discard_idx
peakPowNorm = zeros(size(epochs, 1), 1);
for iepoch = 1 : size(epochs, 1)
    peakPowNorm(iepoch) = max(sig_dtct(epochs(iepoch, 1) : epochs(iepoch, 2)));
end
discard_idx = peakPowNorm < thr(2);
epochs(discard_idx, :) = [];
peakPowNorm(discard_idx) = [];
nepochs = size(epochs, 1);
fprintf('After peak power: %d events\n', nepochs)

% discard ripples that do not maintain peak power for the min duration
clear discard_idx
for iepoch = 1 : size(epochs, 1)
    discard_idx(iepoch) = all(maxk(sig_dtct(epochs(iepoch, 1) : epochs(iepoch, 2)),...
        limDur(1)) > thr(2));
end
epochs(discard_idx, :) = [];
peakPowNorm(discard_idx) = [];
nepochs = size(epochs, 1);
fprintf('After peak power: %d events\n', nepochs)

% clear memory
clear sig_dtct sig_unwrapped

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% stats
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% find negative peak position for each ripple
peakPos = zeros(size(epochs, 1), 1);
peakPow = zeros(size(epochs, 1), 1);
for iepoch = 1 : size(epochs, 1)
    [peakPow(iepoch), peakPos(iepoch)] =...
        min(sig_filt(epochs(iepoch, 1) : epochs(iepoch, 2)));
    peakPos(iepoch) = peakPos(iepoch) + epochs(iepoch, 1) - 1;
end

% convert idx to seconds
peakPos = peakPos / fs;
epochs = epochs / fs;

% -------------------------------------------------------------------------
% maps
ripp.maps.durWin = [-75 75] / 1000;
nbinsMap = floor(fs * diff(ripp.maps.durWin) / 2) * 2 + 1; % must be odd
centerBin = ceil(nbinsMap / 2);
[r, i] = Sync([tstamps sig_filt], peakPos, 'durations', ripp.maps.durWin);
ripp.maps.ripp = SyncMap(r, i, 'durations', ripp.maps.durWin,...
    'nbins', nbinsMap, 'smooth', 0);
[f, i] = Sync([tstamps, sig_freq], peakPos, 'durations', ripp.maps.durWin);
ripp.maps.freq = SyncMap(f, i, 'durations', ripp.maps.durWin,...
    'nbins', nbinsMap, 'smooth', 0);
[a, i] = Sync([tstamps sig_phase], peakPos, 'durations', ripp.maps.durWin);
ripp.maps.phase = SyncMap(a, i,'durations', ripp.maps.durWin,...
    'nbins', nbinsMap, 'smooth', 0);
[p, i] = Sync([tstamps sig_amp], peakPos, 'durations', ripp.maps.durWin);
ripp.maps.amp = SyncMap(p, i,'durations', ripp.maps.durWin,...
    'nbins', nbinsMap, 'smooth', 0);

% clear memory
clear sig_freq sig_amp sig_phase

% -------------------------------------------------------------------------
% more stats
ripp.maxFreq = max(ripp.maps.freq, [], 2);
ripp.peakFreq = ripp.maps.freq(:, centerBin);
ripp.peakAmp = ripp.maps.amp(:, centerBin);
ripp.dur = epochs(:, 2) - epochs(:, 1);

% acg and correlations
[ripp.acg.data, ripp.acg.t] = CCG(peakPos,...
    ones(length(peakPos), 1), 'binSize', 0.01);
ripp.corr.amp_freq = corrcoef(ripp.peakAmp, ripp.peakFreq);
ripp.corr.dur_freq = corrcoef(ripp.dur, ripp.peakFreq);
ripp.corr.dur_amp = corrcoef(ripp.dur, ripp.peakAmp);

% rate of ripples
[ripp.rate.rate, ripp.rate.binedges, ripp.rate.tstamps] =...
    times2rate(peakPos, 'binsize', binsizeRate, 'winCalc', [0, Inf],...
    'c2r', true);

% -------------------------------------------------------------------------
% relation to sleep states
ssfile = fullfile(basepath, [basename '.sleep_states.mat']);
if exist(ssfile)    
    load(ssfile, 'ss')    

    ripp.states.stateNames = ss.info.names;
    nstates = length(ss.stateEpochs);
    
    for istate = sstates
        epochIdx = InIntervals(ss.stateEpochs{istate}, recWin);
        if ~isempty(ss.stateEpochs{istate})
            % rate in states
            [ripp.states.rate{istate}, ripp.states.binedges{istate},...
                ripp.states.tstamps{istate}] =...
                times2rate(peakPos, 'binsize', binsizeRate,...
                'winCalc', ss.stateEpochs{istate}(epochIdx, :), 'c2r', true);
            
            % idx of rippels in state
            ripp.states.idx{istate} =...
                InIntervals(peakPos, ss.stateEpochs{istate}(epochIdx, :));
        end
    end
end

% -------------------------------------------------------------------------
% relation to spiking
if spkFlag
if exist(spktimesfile, 'file')      % mu 
    fprintf('Getting MU spikes in ripples...\n')
    
    load(spktimesfile)
    muSpks = sort(vertcat(spktimes{:})) / fsSpks;
    for iepoch = 1 : nepochs
        ripp.spks.mu.rippAbs{iepoch} = muSpks(muSpks < epochs(iepoch, 2) &...
            muSpks > epochs(iepoch, 1));
        ripp.spks.mu.rippRel{iepoch} = ripp.spks.mu.rippAbs{iepoch} - epochs(iepoch, 1);
    end
    nspksRipp = cellfun(@length, ripp.spks.mu.rippAbs, 'uni', true);
    ripp.spks.mu.rate = nspksRipp ./ ripp.dur';
    
    % count spikes in sampling frequency of lfp
    spkRate = histcounts(muSpks, [0, tstamps']);
    
    % create map of firing rate during ripples
    [r, i] = Sync([tstamps spkRate'], peakPos, 'durations', ripp.maps.durWin);
    ripp.spks.mu.rippMap = SyncMap(r, i, 'durations', ripp.maps.durWin,...
        'nbins', nbinsMap, 'smooth', 0);
    
    % create map of firing rate during random times
    randIdx = sort(randperm(floor(tstamps(end)), nepochs));
    [r, i] = Sync([tstamps spkRate'], randIdx, 'durations', ripp.maps.durWin);
    ripp.spks.mu.randMap = SyncMap(r, i, 'durations', ripp.maps.durWin,...
        'nbins', nbinsMap, 'smooth', 0);

end

if exist(spikesfile, 'file')        % su
    fprintf('Getting SU spikes in ripples...\n')

    load(spikesfile)
    nunits = length(spikes.times);
    spks.su = bz_getRipSpikes('basepath', basepath,...
        'events', epochs, 'spikes', spikes, 'saveMat', false);
    
    ripp.spks.su.rippMap = zeros(nunits, nepochs, nbinsMap);
    ripp.spks.su.randMap = zeros(nunits, nepochs, nbinsMap);
    for iunit = 1 : nunits
        nspksRipp = cellfun(@length, spks.su.UnitEventAbs(iunit, :),...
            'uni', true);
        spks.su.rate(iunit, :) = nspksRipp ./ ripp.dur';       
        
        % count spikes in sampling frequency of lfp
        spkRate = histcounts(spikes.times{iunit}, [0, tstamps']);
        
        % create map of firing rate during ripples
        [r, i] = Sync([tstamps spkRate'], peakPos, 'durations', ripp.maps.durWin);
        ripp.spks.su.rippMap(iunit, :, :) = SyncMap(r, i, 'durations',...
            ripp.maps.durWin, 'nbins', nbinsMap, 'smooth', 0);
        
        % create map of firing rate during random times
        randIdx = sort(randperm(floor(tstamps(end)), nepochs));
        [r, i] = Sync([tstamps spkRate'], randIdx, 'durations', ripp.maps.durWin);
        ripp.spks.su.randMap(iunit, :, :) = SyncMap(r, i, 'durations',...
            ripp.maps.durWin, 'nbins', nbinsMap, 'smooth', 0);        
    end
end
else
    ripp.spks = [];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% finalize and save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ripp.info.rippCh        = rippCh;
ripp.info.limDur        = limDur;
ripp.info.recWin        = recWin;
ripp.info.runtime       = datetime(now, 'ConvertFrom', 'datenum');
ripp.info.thr           = thr;
ripp.info.binsizeRate   = binsizeRate;
ripp.epochs             = epochs + recWin(1);  
ripp.peakPos            = peakPos;
ripp.peakPow            = peakPow;
ripp.peakPowNorm        = peakPowNorm;

if saveVar      
    save(rippfile, 'ripp')

    % create ns files for visualization with neuroscope
    fs_dat = session.extracellular.sr;
    nepochs = size(ripp.epochs, 1);
    
    res = round([ripp.epochs(:, 1); ripp.epochs(:, 2); ripp.peakPos] * fs_dat);
    [res, sort_idx] = sort(round(res));
    fid = fopen(resfile, 'w');
    fprintf(fid, '%d\n', res);
    rc = fclose(fid);
   
    clu = [ones(nepochs, 1); ones(nepochs, 1) * 2; ones(nepochs, 1) * 3];
    clu = clu(sort_idx);
    fid = fopen(clufile, 'w');
    fprintf(fid, '%d\n', 3);
    fprintf(fid, '%d\n', clu);
    rc = fclose(fid);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if graphics
    
    nepochs = size(ripp.epochs, 1);
    setMatlabGraphics(false)
    set(groot, 'DefaultAxesLabelFontSizeMultiplier', 1.1)
    set(groot, 'DefaultAxesTitleFontSizeMultiplier', 1.2)   
    
    % ---------------------------------------------------------------------
    % ripples detection and stats
    fh = figure;
    durPlot = [-50 50] / 1000;
    x = durPlot(1) : diff(durPlot) / nepochs : durPlot(2);
    histBins = 200;
    nbinsMap = size(ripp.maps.freq, 2);
    
    % examples on raw and filtered data
    sb1 = subplot(4, 3, [1, 2]);    
    idx_recMargin = 10 * fs;     % [s]
    nrippPlot = min([round(nepochs / 2), 50]);
    hlfnripp = round(nrippPlot / 2);
    rippSelect = round(hlfnripp) : round(hlfnripp) + nrippPlot;
    rippCenter = round((rippSelect(end) - rippSelect(1)) / 2) + rippSelect(1);
    idx_rec = round([ripp.peakPos(hlfnripp + hlfnripp) * fs - idx_recMargin :...
        ripp.peakPos(hlfnripp + hlfnripp) * fs + idx_recMargin]);
    plot(idx_rec / fs, sig(idx_rec), 'k')
    hold on
    plot(idx_rec / fs, sig_filt(idx_rec), 'm')
    yLimit = ylim;
    plot([ripp.peakPos(rippSelect), ripp.peakPos(rippSelect)], yLimit, 'b')
    plot([ripp.epochs(rippSelect, 1), ripp.epochs(rippSelect, 1)], yLimit, 'g')
    plot([ripp.epochs(rippSelect, 2), ripp.epochs(rippSelect, 2)], yLimit, 'r')
    xlim([ripp.peakPos(rippCenter) - 0.5, ripp.peakPos(rippCenter) + 0.5])
    legend('Raw LFP', 'Filtered')
    xlabel('Time [s]')
    
    % examples of ripples (filtered) superimposed
    sb3 = subplot(4, 3, 3);
    ripp_idx = randperm(nepochs, min([1000, nepochs]));
    plot(((1 : nbinsMap)' - ceil(nbinsMap / 2)) / nbinsMap * diff(durPlot),...
        ripp.maps.ripp(ripp_idx, :)', 'k');
    xlabel('Time [s]')
    
    % rate
    sb4 = subplot(4, 3, [4, 5]);
    plot(ripp.rate.tstamps / 60 / 60, ripp.rate.rate, 'k')
    xlabel('Time [h]')
    ylabel('Ripple Rate [Hz]')
    if exist(ssfile)
        hold on
        for istate = sstates
            ph = plot(ripp.states.tstamps{istate} / 60 / 60,...
                ripp.states.rate{istate}, '.', 'MarkerSize', 5);
            ph.Color = cfg.colors{istate};
        end
        xlabel('Time [h]')
        ylabel('Ripple Rate [Hz]')
        % legend(["Total", ripp.states.stateNames{sstates}]);
    end
    
    % percent rippels in state
    sb6 = subplot(4, 3, 6);
    if exist(ssfile)
        pie(sum(cell2nanmat(ripp.states.idx, 2), 1, 'omitnan'), ones(1, length(sstates)))
        hold on
        ph = findobj(sb6, 'Type', 'Patch');
        set(ph, {'FaceColor'}, flipud(cfg.colors(sstates)))
        legend({ripp.states.stateNames{sstates}}, 'FontSize', 10,...
            'Units', 'normalized', 'Position', [0.661 0.605 0.02 0.10],...
            'NumColumns', 2);
    end
      
    % frequency map
    sb7 = subplot(4, 3, 7);
    PlotColorMap(ripp.maps.freq, 1, 'bar','on', 'cutoffs', [100 250], 'x', x);
    ylabel('Ripple No.')
    title('Frequency');   
    
    % amplitude map
    sb8 = subplot(4, 3, 8);
    PlotColorMap(ripp.maps.amp, 1, 'bar','on', 'x', x);
    ylabel('Ripple No.')
    title('Amplitude');
    
    % ACG
    sb9 = subplot(4, 3, 9);
    plotCCG(ripp.acg.data, ripp.acg.t);
    xlabel('Time [ms]')
    ylabel('Rate')
    
    % distribution of peak frequency
    sb10 = subplot(4, 3, 10);
    h = histogram(ripp.peakFreq, histBins, 'Normalization', 'probability');
    h.FaceColor = 'k';
    h.EdgeColor = 'none';
    xlabel('Peak Frequency [Hz]')
    ylabel('Probability')
    
    % distribution of peak amplitude
    sb11 = subplot(4, 3, 11);
    h = histogram(ripp.peakAmp, histBins, 'Normalization', 'probability');
    h.FaceColor = 'k';
    h.EdgeColor = 'none';
    xlabel('Peak Amp')
    ylabel('Probability')
    
    % distribution of ripple duration
    sb12 = subplot(4, 3, 12);
    h = histogram(ripp.dur * 1000, histBins, 'Normalization', 'probability');
    h.FaceColor = 'k';
    h.EdgeColor = 'none';
    xlabel('Ripple Duration [ms]')
    ylabel('Probability')
    
    sgtitle(basename)
    
    % save figure
    figpath = fullfile(basepath, 'graphics');
    mkdir(figpath)
    figname = fullfile(figpath, sprintf('%s_ripples', basename));
    export_fig(figname, '-tif', '-transparent', '-r300')
    
    % ---------------------------------------------------------------------
    % spikes in ripples
    
    if isfield(ripp.spks, 'mu')
        fh = figure;       
        
        % map of nspks per ripple
        sb1 = subplot(2, 3, 1);
        PlotColorMap(ripp.spks.mu.rippMap, 1, 'bar','on', 'x', x);
        xlabel('Time [ms]')
        ylabel('Ripple No.')
        title('MU Spikes');
        
        % mean nspks across ripples
        sb2 = subplot(2, 3, 2);
        ydata = ripp.spks.mu.rippMap;
        xdata = linspace(ripp.maps.durWin(1), ripp.maps.durWin(2),...
            size(ydata, 2));
        plot(xdata, mean(ydata), 'k')
        hold on
        patch([xdata, flip(xdata)], [mean(ydata) + std(ydata),...
            flip(mean(ydata) - std(ydata))],...
            'k', 'EdgeColor', 'none', 'FaceAlpha', .2, 'HitTest', 'off')
        xlabel('Time [ms]')
        ylabel('MU Spikes')
        axis tight
        
        % hist of nspks in ripples vs. random epochs
        sb3 = subplot(2, 3, 3);
        ydata = sum(ripp.spks.mu.rippMap, 2);
        hh = histogram(ydata, 50,...
            'Normalization', 'probability');
        hh.EdgeColor = 'none';
        hh.FaceColor = 'k';
        hh.FaceAlpha = 0.3;
        hold on
        ydata = sum(ripp.spks.mu.randMap, 2);
        hh = histogram(ydata, 50,...
            'Normalization', 'probability');
        hh.EdgeColor = 'none';
        hh.FaceColor = 'b';
        hh.FaceAlpha = 0.3;
        legend({'Ripple', 'Random'}, 'Location', 'best')
        ylabel('Probability')
        xlabel('MU Spikes')
    end
    
    if isfield(ripp.spks, 'su')
        % map of mean rate per unit across ripples
        sb4 = subplot(2, 3, 4);
        ydata = squeeze(mean(ripp.spks.su.rippMap, 2));
        PlotColorMap(ydata, 1, 'bar','on', 'x', x);
        xlabel('Time [ms]')
        ylabel('Unit No.')
        title('SU Spikes');
        
        % mean nspks across units and ripples
        sb5 = subplot(2, 3, 5);
        xdata = linspace(ripp.maps.durWin(1), ripp.maps.durWin(2),...
            size(ydata, 2));
        ydata = ydata ./ max(ydata, 2);
        plot(xdata, mean(ydata), 'k')
        hold on
        patch([xdata, flip(xdata)], [mean(ydata) + std(ydata),...
            flip(mean(ydata) - std(ydata))],...
            'k', 'EdgeColor', 'none', 'FaceAlpha', .2, 'HitTest', 'off')
        xlabel('Time [ms]')
        ylabel('Norm. SU Spikes')
        axis tight
        
        % hist of nspks in ripples vs. random epochs
        sb6 = subplot(2, 3, 6);
        ydata = squeeze(mean(mean(ripp.spks.su.rippMap, 2), 3));
        xdata = squeeze(mean(mean(ripp.spks.su.randMap, 2), 3));
        plot(xdata, ydata, '.k', 'MarkerSize', 10)
        hold on
        set(gca, 'yscale', 'log', 'xscale', 'log')
        eqLim = [min([ylim, xlim]), max([ylim, xlim])];
        plot(eqLim, eqLim, '--k', 'LineWidth', 1)
        xlim(eqLim)
        ylim(eqLim)
        ylabel('Spikes in Ripples')
        xlabel('Spikes in Random')
    end
    sgtitle(basename)
    
    % save figure
    figpath = fullfile(basepath, 'graphics');
    mkdir(figpath)
    figname = fullfile(figpath, sprintf('%s_rippleSpks', basename));
    export_fig(figname, '-tif', '-transparent', '-r300')
     
        
    end
    
end


% EOF