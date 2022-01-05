% wrapper for batch processing

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mname = 'lh96';
forceL = true;
forceA = false;

pcond = ["tempflag"];
ncond = [""];

% load vars from each session
varsFile = ["fr"; "sr"; "spikes"; "st_metrics"; "swv_metrics";...
    "cell_metrics"; "AccuSleep_states"; "ripp.mat"; "datInfo"; "session"];
varsName = ["fr"; "sr"; "spikes"; "st"; "swv"; "cm"; "ss"; "ripp";...
    "datInfo"; "session"];
if ~exist('varArray', 'var') || forceL
    [v, basepaths] = getSessionVars('mname', mname, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', pcond, 'ncond', ncond);
end
nsessions = length(basepaths);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% general params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'force', true, 'saveVar', true);
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;

sessionIdx = 1 : nsessions;
stateidx = [1, 4, 5];
grp = [1 : 4];                  % which tetrodes to plot
unitClass = 'pyr';              % plot 'int', 'pyr', or 'all'
suFlag = 1;                     % plot only su or all units
frBoundries = [0 Inf];          % include only units with fr greater than

[nsub] = numSubplots(length(sessionIdx));
[cfg_colors, cfg_names, ~] = as_loadConfig([]);
setMatlabGraphics(false)

% arrange title names
for isession = 1 : nsessions
    sessionName{isession} = dirnames{isession}(length(mname) + 2 : end);
    basepath = char(fullfile(mousepath, dirnames{isession}));
    basepaths{isession} = fullfile(mousepath, dirnames{isession});
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% analyze data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if forceA
    for isession = 1 : nsessions
        
        % file
        basepath = basepaths{isession};
        cd(basepath)
        [~, basename] = fileparts(basepath);
        
        % params
        session = v(isession).session;
        nchans = session.extracellular.nChannels;
        fs = session.extracellular.sr;
        spkgrp = session.extracellular.spikeGroups.channels;       
                      
        % call for emg dat file
        [EMG, EEG, sigInfo] = as_prepSig([basename, '.lfp'], [basename, '.emg.dat'],...
            'eegCh', [1 : 4], 'emgCh', 1, 'saveVar', true, 'emgNchans', 2, 'eegNchans', nchans,...
            'inspectSig', false, 'forceLoad', true, 'eegFs', 1250, 'emgFs', 3051.7578125,...
            'emgCf', [10 600]);


    end
end

clear basepaths
k = 1;
sessionIdx = [4];
for isession = sessionIdx  
    basepaths{k} = fullfile(mousepath, dirnames{isession});
    k = k + 1;
end
cell_metrics = CellExplorer('basepaths', basepaths);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% -------------------------------------------------------------------------
% rearrange state of entire experiment
sessionIdx = 1 : nsessions;
stateidx = [1, 4, 5];
ts = 1;                         % state labels epoch length
lightHr = '080000';             % when does light cycle start [HHMM]

assignVars(varArray, sessionIdx(end))

% find date time of start and end of experiment and round it according to
% the light cycle
[dtStart, ~] = guessDateTime(dirnames(sessionIdx(1)));
dtStart = dateshift(dtStart, 'start', 'hour');
dtStart = dtStart + timeofday(guessDateTime(lightHr)) - timeofday(dtStart);
[dtEnd, ~] = guessDateTime(dirnames(sessionIdx(end)));
dtEnd = dtEnd + seconds(length(ss.labels) * ts);
dtEnd = dateshift(dtEnd, 'end', 'hour');
dtEnd = dtEnd + timeofday(guessDateTime(lightHr)) - timeofday(dtEnd);
expLen = seconds(dtEnd - dtStart) / ts;     

% initialize vars that will carry information from entire experiment
expLabels = nan(expLen, 1);
expEmg = nan(expLen, 1);

% concatenate data from different sessions. finds the index of rec start
% from basename and assumes the session recording is continuous
for isession = sessionIdx
    assignVars(varArray, isession)   
    basepath = fullfile(mousepath, dirnames{isession});
    cd(basepath)
    [~, basename] = fileparts(basepath);
    idx_recStart = max([1, seconds(guessDateTime(dirnames(isession)) - dtStart) * ts]);

    % labels
    expLabels(idx_recStart : idx_recStart + length(ss.labels) - 1) = ss.labels;   
    
    % emg
    load([basename, '.AccuSleep_EMG.mat'])
    processedEMG = processEMG(standardizeSR(EMG, 1250, 128), 128, 1);  
    processedEMG = (processedEMG - ss.info.calibrationData(end, 1)) ./...
        ss.info.calibrationData(end, 2);
    processedEMG = (processedEMG + 4.5) ./ 9;    
    processedEMG(processedEMG < 0) = 0;
    processedEMG(processedEMG > 1) = 1;
    expEmg(idx_recStart : idx_recStart + length(processedEMG) - 1) = processedEMG;
end

% percent time of state in timebins
dataNorm = 'm';                     % can be '%' or 'm'
binHr = 3;                          % [h]
binSample = binHr * 60 * 60 / ts;   % [s]
bins = n2chunks('n', expLen, 'chunksize', binSample);
nbins = size(bins, 1);
stateBin = nan(nbins, length(stateidx));
for ibin = 1 : nbins
    % data
    for istate = 1 : length(stateidx)
        stateBin(ibin, istate) =...
            sum(expLabels(bins(ibin, 1) : bins(ibin, 2)) ==...
            stateidx(istate), 'omitnan');
        if strcmp(dataNorm, '%')
            stateBin(ibin, istate) = stateBin(ibin, istate) /...
                sum(~isnan(expLabels(bins(ibin, 1) : bins(ibin, 2))));
        elseif strcmp(dataNorm, 'm')
                 stateBin(ibin, istate) = stateBin(ibin, istate) /...
                60 * ts;
        end
    end
    % time labels
    dt = tstamp2time('dtstr', dtStart, 'tstamp', bins(ibin, 1));
    dt = dateshift(dt, 'start', 'hour');
%     tlabel{ibin} = datestr(datenum(dt), 'dd/mm_HH:MM');   
end
tlabel = datestr(datenum(dtStart : hours(binHr) : dtStart + hours(24)), 'HH:MM');
tlegend = datestr(datenum(dtStart : hours(24) : dtEnd), 'dd/mm');

% create 24 hr cycles 
% saveFig = true;
% fh = figure;
% sessionidx = [1, 2];
% clr = ['rrb'];
% for istate = 1 : length(stateidx)
%     subplot(length(stateidx), 1, istate)
%     stateMat{istate} = reshape(stateBin(:, istate), 24 / binHr, size(stateBin(:, istate), 1) / (24 / binHr));
%     stateMat{istate} = stateMat{istate}(:, sessionidx);
%     ph = plot([1.5 : 24 / binHr + 0.5], stateMat{istate}, 'LineWidth', 2);
%     set(ph, {'Color'}, num2cell(clr)')
%     xticks([1 : 24 / binHr + 1])
%     xticklabels(tlabel)
%     xtickangle(45)
%     title(cfg_names(stateidx(istate)))
%     if istate == 1
%         legend(tlegend, 'Location', 'NorthWest')
%     end
%     ylabel(['State Duration [', dataNorm, ']'])
%     xlabel('Time')
% end
% if saveFig
%     figpath = fullfile(mousepath, 'graphics');
%     mkdir(figpath)
%     figname = fullfile(figpath, ['stateDuration_perDay']);
%     export_fig(figname, '-tif', '-transparent', '-r300')
% end
    
% graphics
fh = figure;
subplot(4, 1, 1)
hold on
for istate = stateidx
    stateLabels = find(expLabels == istate);
    scatter(stateLabels / fs / 60 / 60,...
        expEmg(stateLabels),...
        3, cfg_colors{istate})
end
xlim([1 / fs / 60 / 60, length(expLabels) / fs / 60 / 60])
ylim([min(expEmg) 1])
ylabel('Norm. EMG RMS')
set(gca, 'XTick', [], 'YTick', [])

subplot(4, 1, [2 : 4])
xidx = bins(:, 2) - binSample / binHr;
ph = plot(xidx, stateBin, 'Marker', '.', 'LineStyle', '-', 'MarkerSize', 20);
set(ph, {'MarkerEdgeColor'}, cfg_colors(stateidx),...
    {'MarkerFaceColor'}, cfg_colors(stateidx), {'Color'}, cfg_colors(stateidx))
axis tight
hold on
plot([bins(1 : 2 : end, 1), bins(1 : 2 : end, 1)], ylim, '--k', 'LineWidth', 0.5)
xticks(bins(1 : 2 : end, 1))
xticklabels(tlabel(1 : 2 : end, :))
xtickangle(45)
xlabel('Time')
ylabel(['State Duration [', dataNorm, ']'])

if saveFig
    figpath = fullfile(mousepath, 'graphics');
    mkdir(figpath)
    figname = fullfile(figpath, ['stateDuration_aligned']);
    export_fig(figname, '-tif', '-transparent', '-r300')
end

% -------------------------------------------------------------------------
% stacked bar plot of state duration across sessions
figFlag = 1; saveFig = true;
stateidx = [1 : 6];
sessionIdx = 1 : nsessions;
[nsub] = numSubplots(length(sessionIdx));
if figFlag
    clear stateDur
    for isession = sessionIdx
        assignVars(varArray, isession)
        for istate = stateidx 
            stateDur(isession, istate) = sum(ss.epLen{istate}) /...
                length(ss.labels) * 100;
        end               
    end
    
    fh = figure;
    bh = bar(stateDur, 'stacked', 'FaceColor', 'flat');
    for isession = sessionIdx
        for istate = stateidx          
            bh(istate).CData(isession, :) = cfg_colors{istate};
        end
    end
    xticks([1 : length(sessionIdx)]);
    xticklabels(cellstr(dirnames))
    xtickangle(45)
    ylim([0 100])
    ylabel('Time [%]')
    legend(ss.labelNames)
    title('State Duration')
    
    if saveFig
        figpath = fullfile(mousepath, 'graphics');
        mkdir(figpath)
        figname = fullfile(figpath, ['stateDuration']);
        export_fig(figname, '-tif', '-transparent', '-r300')
    end
end

% -------------------------------------------------------------------------
% distribution of mu bins in each state
figFlag = 1; saveFig = true;
grp = 1 : 4;
stateidx = [1 : 6];
sessionIdx = 1 : nsessions;
[nsub] = numSubplots(length(sessionIdx));
plotStyle = 'box';      % can be 'histogram' or 'box'

if figFlag
    fh = figure;
    for isession = 1 : length(sessionIdx)
        
        assignVars(varArray, sessionIdx(isession))
        subplot(nsub(1), nsub(2), isession)
        hold on
        for istate = stateidx
            srmat = sr.states.fr{istate}(grp, :);
            srStates{istate} = srmat(:);
            
            if strcmp(plotStyle, 'histogram')
                binstates{isession, istate} = mean(sr.states.fr{istate}(grp, :), 1);
                h = histogram(binstates{isession, istate}, 20,...
                    'EdgeAlpha', 0, 'faceColor', cfg_colors{istate}, 'FaceAlpha',...
                    0.3, 'Normalization', 'probability');
            end
        end
        
        if strcmp(plotStyle, 'histogram')
            set(gca, 'xscale', 'log', 'box', 'off', 'TickLength', [0 0])
            xlim([10 250])
            ylabel('Counts')
            xlabel('Spike Rate [Hz]')          
            
        elseif strcmp(plotStyle, 'box')
            srmat = cell2nanmat(srStates(stateidx));
            boxplot(srmat, 'PlotStyle', 'traditional', 'Whisker', 6);
            bh = findobj(gca, 'Tag', 'Box');
            bh = flipud(bh);
            for istate = 1 : length(stateidx)
                patch(get(bh(istate), 'XData'), get(bh(istate), 'YData'),...
                    cfg_colors{stateidx(istate)}, 'FaceAlpha', 0.5)
            end
            xticks([])
            ylabel('MU spike rate [Hz]')
            ylim([0 180])
        end
        
        title(sessionDate{sessionIdx(isession)})
        if isession == 1
            legend(ss.labelNames(stateidx))
        end
    end
    
    if saveFig
        figpath = fullfile(mousepath, 'graphics');
        mkdir(figpath)
        figname = fullfile(figpath, ['mu_states']);
        export_fig(figname, '-tif', '-transparent', '-r300')
    end   
end

% -------------------------------------------------------------------------
% distribution of su firing rate per state
figFlag = 1; saveFig = true;
stateidx = [1 : 6];
sessionIdx = 1 : nsessions;
[nsub] = numSubplots(length(sessionIdx));
grp = [1 : 4];          % which tetrodes to plot
unitClass = 'int';      % plot 'int', 'pyr', or 'all'
suFlag = 0;             % plot only su or all units
frBoundries = [0 Inf];  % include only units with mean fr in these boundries

if figFlag
    fh = figure;
    clear frState
    for isession = 1 : length(sessionIdx)
        assignVars(varArray, sessionIdx(isession))
        units = selectUnits(spikes, cm, fr, suFlag, grp, frBoundries, unitClass);
        nunits = sum(units);
        
        for istate = stateidx
            frState{isession}(:, istate) = mean(fr.states.fr{istate}(units, :), 2, 'omitnan');
        end
        subplot(nsub(1), nsub(2), isession)
        hold on
        boxplot(frState{isession}(:, stateidx), 'PlotStyle', 'traditional', 'Whisker', 8);
        bh = findobj(gca, 'Tag', 'Box');
        bh = flipud(bh);
        for ibox = 1 : length(bh)
            patch(get(bh(ibox), 'XData'), get(bh(ibox), 'YData'),...
                cfg_colors{stateidx(ibox)}, 'FaceAlpha', 0.5)
        end
        xticks([])
        ylabel([unitClass, ' firing rate [Hz]'])
        ylim([0 15])
        title(sessionDate{sessionIdx(isession)})
        if isession == 1
            legend(ss.labelNames(stateidx))
        end
    end
    if saveFig
        figpath = fullfile(mousepath, 'graphics');
        mkdir(figpath)
        figname = fullfile(figpath, [unitClass, '_states']);
        export_fig(figname, '-tif', '-transparent', '-r300')
    end
end


