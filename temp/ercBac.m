
basepaths = {'F:\Data\lh96\lh96_220120_090157',...
    'F:\Data\lh96\lh96_220121_090213',...
    'F:\Data\lh96\lh96_220122_090154',...
    'F:\Data\lh96\lh96_220123_090009',...
    'F:\Data\lh96\lh96_220124_090127',...
    'F:\Data\lh96\lh96_220125_090041',...
    'F:\Data\lh96\lh96_220126_085016',...
    };


% load vars from each session
varsFile = ["datInfo"; "session"];
varsName = ["datInfo"; "session"];
[v, ~] = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
    'varsName', varsName);
nsessions = length(basepaths);

% analyze
for isession = [1 : nsessions]

    % file
    basepath = basepaths{isession};
    cd(basepath)
    [~, basename] = fileparts(basepath);

    % params
    session = v(isession).session;
    nchans = session.extracellular.nChannels;
    fs = session.extracellular.sr;
    spkgrp = session.extracellular.spikeGroups.channels;

    % add timebins to datInfo
    nbins = 4;
    reqPnt = [];
    [timebins, timepnt] = metaInfo_timebins('reqPnt', reqPnt,...
        'nbins', nbins);
    winCalc = mat2cell(timebins, ones(nbins, 1), 2);

    % spk lfp
    frange = [0.5, 2; 2, 4; 4, 8; 5, 11; 12, 18; 20, 35; 35, 50; 50, 70; 70, 100; 150, 250];
    s = spklfp_wrapper('basepath', basepath, 'winCalc', winCalc,...
        'ch', 9, 'frange', frange,...
        'graphics', true, 'saveVar', false);
    
    % spike timing metrics
    st = spktimesMetrics('winCalc', winCalc, 'forceA', true);

end

% load vars from each session
varsFile = ["datInfo"; "session"; "spklfp"; "st_metrics"; "units"];
varsName = ["datInfo"; "session"; "s"; "st"; "units"];
[v, ~] = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
    'varsName', varsName);
nsessions = length(basepaths);

brstVar = 'royer';
unitType = 'rs';

nbins = 4;
cnt = 1;
clear mrld mrlt brst mrls
for isession = 1 : nsessions
    nunits = length(v(isession).s(ibin).phase.mrl(:, 1));
    
    su = v(isession).units.(unitType);
    
    for ibin = 1 : nbins
        mrls{cnt} = v(isession).s(ibin).phase.mrl(:, 1);
        mrld{cnt} = v(isession).s(ibin).phase.mrl(:, 2);
        mrlt{cnt} = v(isession).s(ibin).phase.mrl(:, 4);
        brst{cnt} = v(isession).st.(brstVar)(ibin, su);
        cnt = cnt + 1;
    end
end

mrls = cell2nanmat(mrls, 2);
mrld = cell2nanmat(mrld, 2);
mrlt = cell2nanmat(mrlt, 2);
brst = cell2nanmat(brst, 2);

xdata = [-5 * 6 : 6 : 136];

% graphics
setMatlabGraphics(true)
fh = figure;
th = tiledlayout(4, 1, 'TileSpacing', 'Compact');

nexttile
plot_boxMean('dataMat', mrls, 'clr', 'm', 'allPnts', true)
xticklabels(xdata);
ylabel('SWA [0.5-2 Hz] MRL')

nexttile
plot_boxMean('dataMat', mrld, 'clr', 'r', 'allPnts', true)
xticklabels(xdata);
ylabel('Delta [2-4 Hz] MRL')

nexttile
plot_boxMean('dataMat', mrlt, 'clr', 'b', 'allPnts', true)
xticklabels(xdata);
ylabel('Theta [5-12 Hz] MRL')

nexttile
plot_boxMean('dataMat', brst, 'clr', 'k', 'allPnts', true)
xticklabels(xdata);
xlabel('Time [h]')
ylabel('Burstiness')


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% short time reprasentative
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

basepath = 'F:\Data\lh96\lh96_220126_085016';
cd(basepath)
[~, basename] = fileparts(basepath);
lfpfile = fullfile(basepath, [basename, '.lfp']);
datfile = fullfile(basepath, [basename, '.dat']);

% load vars 
varsFile = ["datInfo"; "session"; "spikes"; "units"];
varsName = ["datInfo"; "session"; "spikes"; "units"];
[v, ~] = getSessionVars('basepaths', {basepath}, 'varsFile', varsFile,...
    'varsName', varsName);

% params from session info
nchans = v.session.extracellular.nChannels;
fsLfp = v.session.extracellular.srLfp;
fs = v.session.extracellular.sr;

winCalc = [1, 30 * 60];
recDur = diff(winCalc);

% load
rawData = double(bz_LoadBinary(datfile, 'duration', recDur,...
    'frequency', fs, 'nchannels', nchans, 'start', winCalc(1),...
    'channels', 7, 'downsample', 1));

recDur = diff(winCalc);
lfpData = double(bz_LoadBinary(lfpfile, 'duration', recDur,...
    'frequency', fsLfp, 'nchannels', nchans, 'start', winCalc(1),...
    'channels', [1 : 15], 'downsample', 1));
lfpData = mean(lfpData, 2);

% filter
swa = filterLFP(lfpData, 'fs', fsLfp, 'type', 'butter', 'dataOnly', true,...
    'order', 3, 'passband', [0.5, 2], 'graphics', false);
theta = filterLFP(lfpData, 'fs', fsLfp, 'type', 'butter', 'dataOnly', true,...
    'order', 3, 'passband', [5, 11], 'graphics', false);


winPlot = 28 * 60;
winPlot = [winPlot, winPlot + 60];

% arrange spike times
spktimes = cellfun(@(x) [x(InIntervals(x, winPlot))]',...
    v.spikes.times, 'uni', false)';
[rs, sidx] = sort(v.units.rs, 'descend');
rs = logical(rs);
spktimes = spktimes(sidx);


% graphics
setMatlabGraphics(false)
fh = figure;
th = tiledlayout(4, 1, 'TileSpacing', 'Compact');

% raw data
nh1 = nexttile;
xWin = winPlot * fs;
xval = [xWin(1) : xWin(2)] / fs;
plot(xval, rawData(xWin(1) : xWin(2)))
ylabel('Amplitude [uV]')
yticks([])
title('Raw Data')

% sw
nh2 = nexttile;
xWin = winPlot * fsLfp;
xval = [xWin(1) : xWin(2)] / fsLfp;
plot(xval, swa(xWin(1) : xWin(2)))
ylabel('Amplitude [uV]')
yticks([])
title('SWA [0.5-2 Hz]')

% theta
nh3 = nexttile;
plot(xval, theta(xWin(1) : xWin(2)))
yticks([])
ylabel('Amplitude [uV]')
title('Theta [5-11 Hz]')

% raster plot
LineFormat = struct();
LineFormat.Color = [0.1 0.1 0.8];
nh4 = nexttile;
plotSpikeRaster(spktimes(rs),...
    'PlotType', 'vertline', 'LineFormat', LineFormat);
hold on
LineFormat.Color = [0.8 0.1 0.1];
plotSpikeRaster(spktimes(~rs),...
    'PlotType', 'vertline', 'LineFormat', LineFormat,...
    'VertSpikePosition', sum(rs));
ylim([0, length(rs)])
yticks([])
ylabel('Cell Number')
title('RasterPlot]')
xlabel('Time [s]')

linkaxes([nh1, nh2, nh3, nh4], 'x')

