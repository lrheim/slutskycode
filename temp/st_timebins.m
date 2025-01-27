
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data base
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% local ket
basepaths = [{'I:\lh96\lh96_211126_072000'},...
    {'F:\Data\Processed\lh96\lh96_211202_070500'},...
    {'K:\Data\lh95\lh95_210825_080400'},...
    {'K:\Data\lh99\lh99_211219_085802'}];

% baclofen
basepaths = [{'F:\Data\Processed\lh96\lh96_211207_071500'},...
    {'K:\Data\lh99\lh99_211220_091903'},...
    {'G:\Data\lh98\lh98_211220_104619'}];
basepaths = basepaths(1 : 2);

% local acsf
basepaths = [{'K:\Data\lh99\lh99_211218_090630'},...
    {'F:\Data\Processed\lh96\lh96_211201_070100'},...
    {'K:\Data\lh95\lh95_210824_083300'},...
    {'G:\Data\lh93\lh93_210811_102035'}];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% laod
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

forceL = true;

% load vars from each session
varsFile = ["fr"; "spikes"; "st_metrics";...
    "cell_metrics"; "sleep_states"; "ripp.mat"; "datInfo"; "session"];
varsName = ["fr"; "spikes"; "st"; "cm"; "ss"; "ripp";...
    "datInfo"; "session"];
if ~exist('v', 'var') || forceL
    v = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
        'varsName', varsName);
end
nsessions = length(basepaths);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get st
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% params
frBoundries = [0.1, Inf; 0.1, Inf];
svars = {'royer', 'lidor', 'lvr'};
tbins_txt = {'0-3ZT', '3-6ZT', '6-9ZT', '9-12ZT',...
            '12-15ZT', '15-18ZT', '18-21ZT', '21-24ZT'};

units = [];
clear stBins;
stBins.royer = [];
stBins.lidor = [];
stBins.lvr = [];
clear winCalc
for isession = 1 : nsessions
    
    % session params
    basepath = basepaths{isession};
    cd(basepath)
    [~, basename] = fileparts(basepath);
    
    fs = v(isession).session.extracellular.sr;
    fsLfp = v(isession).session.extracellular.srLfp;
    spkgrp = v(isession).session.extracellular.spikeGroups.channels;
    nchans = v(isession).session.extracellular.nChannels;
    
    if contains(basename, 'lh99')
        grp = [1, 3 : 4, 7]; 
    else
        grp = [];
    end

    % timebins
    fileinfo = dir([basename, '.dat']);
    recLen = floor(fileinfo.bytes / 2 / nchans / fs);
    csec = floor(cumsum(v(isession).datInfo.nsamps / fs));
    [~, pntIdx] = min(abs(csec - 5.5 * 60 * 60));
    timepoints = csec(pntIdx);
    chunks = n2nchunks('n', recLen, 'nchunks', 8, 'timepoints', timepoints);
    nchunks = size(chunks, 1);
    
    stateIdx = [1];
    for ichunk = 1 : nchunks
        winIdx = InIntervals(v(isession).ss.boutTimes{stateIdx}, chunks(ichunk, :));
        winCalc{ichunk} = v(isession).ss.boutTimes{stateIdx}(winIdx, :);
    end
    
    st = spktimesMetrics('winCalc', winCalc, 'fs', fs, 'forceA', true);
    
    clear tmp_units
    tmp_units(1, :) = selectUnits(v(isession).spikes, v(isession).cm,...
        v(isession).fr, 1, grp, frBoundries, 'pyr');
    tmp_units(2, :) = selectUnits(v(isession).spikes, v(isession).cm,...
        v(isession).fr, 1, grp, frBoundries, 'int');
    units = [units, tmp_units];
    nunits(isession) = length(tmp_units);
   
    fh = figure;
    for isvar = 1 : length(svars)
        subplot(length(svars), 2, 1 + (isvar - 1) * 2)
        dataMat = st.(svars{isvar})(:, tmp_units(1, :));
        plot_boxMean('dataMat', dataMat', 'clr', 'b')
        ylabel(svars(isvar))
        sgtitle(basename)
        
        subplot(length(svars), 2, 2 + (isvar - 1) * 2)
        dataMat = st.(svars{isvar})(:, tmp_units(2, :));
        plot_boxMean('dataMat', dataMat', 'clr', 'r')
        ylabel(svars(isvar))
        sgtitle(basename)
        
    end

    for isvar = 1 : length(svars)
        stBins.(svars{isvar}) = [stBins.(svars{isvar}), st.(svars{isvar})];
    end
end
units = logical(units);


fh = figure;
for isvar = 1 : length(svars)
    subplot(length(svars), 2, 1 + (isvar - 1) * 2)
    dataMat = stBins.(svars{isvar})(:, units(1, :));
    plot_boxMean('dataMat', dataMat', 'clr', 'b')
    ylabel(svars(isvar))
    sgtitle(basename)
    xticklabels(tbins_txt)
    
    subplot(length(svars), 2, 2 + (isvar - 1) * 2)
    dataMat = stBins.(svars{isvar})(:, units(2, :));
    plot_boxMean('dataMat', dataMat', 'clr', 'r')
    ylabel(svars(isvar))
    sgtitle(basename)
    xticklabels(tbins_txt)
end

