
% psd_states_timebins

% wrapper for calculating the psd per state in different time bins of a
% session.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% session
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

basepath = 'F:\Data\lh99\lh99_211223_090020';
cd(basepath)
[~, basename] = fileparts(basepath);

% load vars from each session
varsFile = ["AccuSleep_states"; "datInfo"; "session"];
varsName = ["ss"; "datInfo"; "session"];
v = getSessionVars('basepaths', {basepath}, 'varsFile', varsFile,...
    'varsName', varsName);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calc psd
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fs = v.session.extracellular.sr;
fsLfp = v.session.extracellular.srLfp;
fsEeg = 6103.515625;
spkgrp = v.session.extracellular.spikeGroups.channels;
nchans = v.session.extracellular.nChannels;

% recording length
datInfo = v.datInfo;
fileinfo = dir([basename, '.dat']);
recLen = floor(fileinfo.bytes / 2 / nchans / fs);

% separate recording to timebins
nbins = 4;
csec = floor(cumsum(v.datInfo.nsamps) / fs);
[~, injIdx] = min(abs(csec - 6 * 60 * 60));
injTime = csec(injIdx);
timebins = n2chunks('n', recLen, 'chunksize', ceil(recLen / nbins));
timebins(1, 2) = floor(injTime);
timebins(2, 1) = ceil(injTime) + 1;
timebins(end, end) = length(v.ss.labels);

tbins_txt = {'0-6 ZT', '6-12 ZT', '12-18 ZT', '18-24 ZT'};

faxis = 0.2 : 0.2 : 120;
sstates = [1, 4, 5];
psdLfp = nan(nbins, length(sstates), length(faxis));
psdEeg = nan(nbins, length(sstates), length(faxis));
for iwin = 1 : nbins
    
    labels = v.ss.labels(timebins(iwin, 1) : timebins(iwin, 2));
    chLfp = v.ss.info.eegCh;
    chEeg = 34;
    
    % ---------------------------------------------------------------------
    % hippocampal lfp
    sig = double(bz_LoadBinary([basename, '.lfp'],...
        'duration', diff(timebins(iwin, :)) + 1,...
        'frequency', fsLfp, 'nchannels', nchans, 'start', timebins(iwin, 1),...
        'channels', chLfp, 'downsample', 1));
    sig = mean(sig, 2);
    tstamps_sig = [1 : length(sig)] / fsLfp;

    [psdLfp(iwin, :, :), ~, ~, epStats(iwin)] = psd_states('eeg', sig, 'emg', [],...
        'labels', labels, 'fs', fsLfp, 'faxis', faxis,...
        'graphics', false, 'sstates', sstates);

    % ---------------------------------------------------------------------
    % frontal eeg
    chLfp = v.ss.info.eegCh;
    if chEeg < 3
        sig = double(bz_LoadBinary([basename, '.emg.dat'],...
            'duration', diff(timebins(iwin, :)) + 1,...
            'frequency', fsEeg, 'nchannels', 2, 'start', timebins(iwin, 1),...
            'channels', chEeg, 'downsample', 1));
        sig = [interp1([1 : length(sig)] / fsEeg, sig, tstamps_sig, 'spline')]';
    else
        sig = double(bz_LoadBinary([basename, '.lfp'],...
            'duration', diff(timebins(iwin, :)) + 1,...
            'frequency', fsLfp, 'nchannels', nchans, 'start', timebins(iwin, 1),...
            'channels', chEeg, 'downsample', 1));
    end
    [psdEeg(iwin, :, :), ~, ~, ~] = psd_states('eeg', sig, 'emg', [],...
        'labels', labels, 'fs', fsLfp, 'faxis', faxis,...
        'graphics', false, 'sstates', sstates);
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arrange in struct and save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% organize epoch lengths according to time bins
for iwin = 1 : nbins
    for istate = 1 : length(sstates)
        epLen_temp{iwin, istate} = epStats(iwin).epLen{sstates(istate)};
    end
    totDur(iwin, :) = epStats(iwin).totDur(sstates);
end
for istate = 1 : length(sstates)
    epLen{istate} = cell2nanmat(epLen_temp(:, istate));
end

psdBins.info.runtime = datetime(now, 'ConvertFrom', 'datenum');
psdBins.info.chLfp = chLfp;
psdBins.info.chEeg = chEeg;
psdBins.info.fsLfp = fsLfp;
psdBins.info.fsEeg = fsEeg;
psdBins.timebins = timebins;
psdBins.psdLfp = psdLfp;
psdBins.psdEeg = psdEeg;
psdBins.epStats = epStats;
psdBins.epLen_organized = epLen;
psdBins.totDur_organized = totDur;

psdfile = fullfile(basepath, [basename, '.psdBins.mat']);
save(psdfile, 'psdBins')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
setMatlabGraphics(false)
alphaIdx = linspace(0.5, 1, nbins);
[cfg_colors, cfg_names, ~] = as_loadConfig([]);
lim_fAxis = faxis > 1;
smf = 7;
gk = gausswin(smf);
gk = gk / sum(gk);

fh = figure;
for istate = 1 : length(sstates)
    
    % lfp
    subplot(3, 3, istate)
    psdMat = squeeze(psdBins.psdLfp(:, istate, lim_fAxis));
    %     for iwin = 1 : nbins
    %         psdMat(iwin, :) = conv(psdMat(iwin, :), gk, 'same');
    %     end
    %     psdMat = psdMat ./ sum(psdMat, 2);
    ph = plot(faxis(lim_fAxis), psdMat', 'LineWidth', 2);
    for iwin = 1 : length(ph)
        ph(iwin).Color(istate) = cfg_colors{sstates(istate)}(istate) - iwin * 0.003;
        ph(iwin).Color(4) = alphaIdx(iwin);
    end
    title(cfg_names{sstates(istate)})
    xlabel('Frequency [Hz]')
    ylabel('LFP PSD [mV^2/Hz]')
    legend(tbins_txt, 'Location', 'Southwest')
    set(gca, 'YScale', 'log', 'XScale', 'log')
    xlim([faxis(find(lim_fAxis, 1)), faxis(find(lim_fAxis, 1, 'last'))])
   
    % eeg
    subplot(3, 3, istate + 3)
    psdMat = squeeze(psdBins.psdEeg(:, istate, lim_fAxis));
    %     for iwin = 1 : nbins
    %         psdMat(iwin, :) = conv(psdMat(iwin, :), gk, 'same');
    %     end
    %     psdMat = psdMat ./ sum(psdMat, 2);
    ph = plot(faxis(lim_fAxis), psdMat', 'LineWidth', 2);
    for iwin = 1 : length(ph)
        ph(iwin).Color(istate) = cfg_colors{sstates(istate)}(istate) - iwin * 0.003;
        ph(iwin).Color(4) = alphaIdx(iwin);
    end
    xlabel('Frequency [Hz]')
    ylabel('EEG PSD [mV^2/Hz]')
    set(gca, 'YScale', 'log', 'XScale', 'log')
    xlim([faxis(find(lim_fAxis, 1)), faxis(find(lim_fAxis, 1, 'last'))])
    
    % state duration
    subplot(3, 3, istate + 6)
    epMat = epLen{istate};
    boxplot(epMat, 'PlotStyle', 'traditional', 'Whisker', 6);
    bh = findobj(gca, 'Tag', 'Box');
    bh = flipud(bh);
    for ibox = 1 : length(bh)
        patch(get(bh(ibox), 'XData'), get(bh(ibox), 'YData'),...
            cfg_colors{sstates(istate)}, 'FaceAlpha', alphaIdx(ibox))
    end
    ylabel('Epoch Length [log(s)]')
    set(gca, 'YScale', 'log')
    ylim([0 ceil(prctile(epMat(:), 99.99))])
    yyaxis right
    plot([1 : size(epMat, 2)], totDur(:, istate) / 60,...
        'kd', 'markerfacecolor', 'k')
    ylabel('State duration [min]')
    ax = gca;
    set(ax.YAxis(1), 'color', cfg_colors{sstates(istate)})
    set(ax.YAxis(2), 'color', 'k')
    xticklabels(tbins_txt)
    xtickangle(45)
    
end

saveFig = true;
if saveFig
    figpath = fullfile(basepath, 'graphics', 'sleepState');
    mkdir(figpath)
    figname = fullfile(figpath, [basename, '_psdBins']);
    export_fig(figname, '-jpg', '-transparent', '-r300')
end




