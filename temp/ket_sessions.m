% ket_sessions

forceL = false;
frBoundries = [0.01 Inf; 0.01 Inf];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data base
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% i.p. 10 mg/kg
% F:\Data\lh99\lh99_211224_084528
% F:\Data\Processed\lh96\lh96_211206_070400

% lh94
% lh94_210812_081900 - ket 20 mM @ 1 ul - can use t3 from. note ripples
% lh94_210813_090800 - saline @ 1 ul


% lh95
% F:\Data\lh95\lh95_210824_083300
% F:\Data\lh95\lh95_210825_080400

basepaths{1} = 'F:\Data\lh95\lh95_210824_083300';
basepaths{2} = 'F:\Data\lh95\lh95_210825_080400';

% load vars from each session
varsFile = ["fr"; "sr"; "spikes"; "st_metrics"; "swv_metrics";...
    "cell_metrics"; "AccuSleep_states"; "ripp.mat"; "datInfo"; "session"];
varsName = ["fr"; "sr"; "spikes"; "st"; "swv"; "cm"; "ss"; "ripp";...
    "datInfo"; "session"];
if ~exist('varArray', 'var') || forceL
    v = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
        'varsName', varsName);
end
nsessions = length(basepaths);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% firing rate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% re-anaylze session in segments
for isession = 1 : nsessions
    
    % session params
    basepath = basepaths{isession};
    cd(basepath)
    [~, basename] = fileparts(basepath);
    
    fs = v(isession).session.extracellular.sr;
    fsLfp = v(isession).session.extracellular.srLfp;
    spkgrp = v(isession).session.extracellular.spikeGroups.channels;
    nchans = v(isession).session.extracellular.nChannels;
    
    % separate recording to quartiles
    nbins = 4;
    datInfo = v(isession).datInfo;
    fileinfo = dir([basename, '.dat']);
    recLen = floor(fileinfo.bytes / 2 / nchans / fs);
    injTime = floor(v(isession).datInfo.nsamps(1) / fs);
    timebins = n2chunks('n', recLen, 'chunksize', ceil(recLen / nbins));
    timebins(1, 2) = floor(injTime);
    timebins(2, 1) = ceil(injTime) + 1;

    faxis = 0.2 : 0.2 : 120;
    sstates = [1, 4, 5];
    psdStates = nan(nbins, 3, length(faxis));
    for iwin = 1 : nbins
        
        % firing rate
%         fr(isession, iwin) = firingRate(v(isession).spikes.times,...
%             'basepath', basepath, 'graphics', false,...
%             'binsize', 60, 'saveVar', true, 'smet', 'GK', 'winBL',...
%             [0, Inf], 'winCalc', qrtls(iwin, :));        
        
        % psd
        chLfp = v(isession).ss.info.eegCh;
        lfpSig = double(bz_LoadBinary([basename, '.lfp'],...
            'duration', diff(timebins(iwin, :)) + 1,...
            'frequency', fsLfp, 'nchannels', nchans, 'start', timebins(iwin, 1),...
            'channels', chLfp, 'downsample', 1));
        lfpSig = mean(lfpSig, 2);
        labels = v(isession).ss.labels(timebins(iwin, 1) : timebins(iwin, 2));
        [psdStates(iwin, :, :), ~, ~, epStats(iwin)] = psd_states('eeg', lfpSig, 'emg', [],...
            'labels', labels,...
            'fs', fsLfp, 'faxis', faxis,...
            'graphics', true, 'sstates', sstates);
    end
    psdStruct.timebins = timebins;
    
    psdfile = fullfile(basepath, [basename, '.psd_timebins.mat']);
    save(psdfile, 'psdStates', 'epStats')
    
    % graphics
    fh = figure;
    alphaIdx = linspace(0.4, 1, nbins);
    [cfg_colors, cfg_names, ~] = as_loadConfig([]);
    for istate = 1 : length(sstates)
        subplot(1, 3, istate)
        psdMat = squeeze(psdStates(:, istate, :)) ./ sum(squeeze(psdStates(:, istate, :)), 2);
        ph = plot(faxis, psdMat', 'LineWidth', 2);
        for iqrt = 1 : length(ph)
            ph(iqrt).Color(1) = cfg_colors{sstates(istate)}(1) - iqrt * 0.05;
            ph(iqrt).Color(2) = cfg_colors{sstates(istate)}(2) - iqrt * 0.05;
            ph(iqrt).Color(3) = cfg_colors{sstates(istate)}(3) - iqrt * 0.05;
            ph(iqrt).Color(4) = alphaIdx(iqrt);
        end
        title(cfg_names{sstates(istate)})
        xlabel('Frequency [Hz]')
        ylabel('norm. PSD')
        legend
        set(gca, 'YScale', 'log')
    end
    
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% firing rate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% re-organize vars of interest
for isession = 1 : nsessions

    % arrange
    ridx = [1, 4];
    % units
    clear units
    units(1, :) = selectUnits(v(isession).spikes, v(isession).cm,...
        v(isession).fr, 1, [], frBoundries, 'pyr');
    units(2, :) = selectUnits(v(isession).spikes, v(isession).cm,...
        v(isession).fr, 1, [], frBoundries, 'int');
    
    clear sratio_rs sratio_fs
    for iwin = 1 : nbins
        sratio_rs(iwin, :) = squeeze(fr(isession, iwin).states.ratio(ridx(1), ridx(2), units(1, :)));
        sratio_fs(iwin, :) = squeeze(fr(isession, iwin).states.ratio(ridx(1), ridx(2), units(2, :)));
        
%         sratio_rs(iwin, :) = fr(iwin).states.gain(4, units(1, :));
%         sratio_fs(iwin, :) = fr(iwin).states.gain(4, units(2, :));
    end
    
    yLimit = [min([sratio_rs, sratio_fs], [], 'all'), max([sratio_rs, sratio_fs], [], 'all')];
    
    % graphics
    fh = figure;
    subplot(1, 2, 1)
    plot([1 : nbins], mean(sratio_rs, 2, 'omitnan'),...
        'kd', 'markerfacecolor', 'k')
    boxplot(sratio_rs', 'PlotStyle', 'traditional', 'Whisker', 6);
    ylabel('AWAKE - NREM')
    ylim(yLimit)
    subtitle('rs')

    subplot(1, 2, 2)
    plot([1 : nbins], mean(sratio_fs, 2, 'omitnan'),...
        'kd', 'markerfacecolor', 'k')
    boxplot(sratio_fs', 'PlotStyle', 'traditional', 'Whisker', 6);
    ylabel('AWAKE - NREM')
    ylim(yLimit)
    subtitle('fs')
    title(basename)
end





