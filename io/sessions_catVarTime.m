function [expData, tidx, tidxLabels] = sessions_catVarTime(varargin)

% concatenates a variable from different sessions. assumes sessions are
% contineous. concatenates according to the time of day extracted from
% basenames. current variables supported are sr and spectrogram.
% 
% INPUT
%   basepaths       cell of chars to recording sessions
%   mname           char of mouse name. if basepaths is empty will get
%                   basepaths from the sessionList.xlsx file
%   xTicksBinsize   numeric. x-axis ticks every binsize hr
%   graphics        logical {true}
%   saveFig         logical {true}
%   dataPreset      string or cell of string depicting the variable to cat. 
%                   can be any combination of 'sr', 'spec', 'fr', 'ripp',
%                   or 'emg'
%   axh             handle to plot axis
% 
% EXAMPLE
% mname = 'lh96';
% [srData, tidx, tidxLabels] = sessions_catVarTime('mname', mname, 'dataPreset', 'both', 'graphics', false);
% 
% TO DO LIST
%   organize output
% 
% UPDATES
%   12 feb 22       added ripples

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addParameter(p, 'basepaths', {}, @iscell);
addParameter(p, 'mname', '', @ischar);
addParameter(p, 'dataPreset', 'sr');
addParameter(p, 'xTicksBinsize', 12, @isnumeric);
addParameter(p, 'graphics', true, @islogical);
addParameter(p, 'saveFig', true, @islogical);
addParameter(p, 'axh', []);

parse(p, varargin{:})
basepaths       = p.Results.basepaths;
mname           = p.Results.mname;
dataPreset      = p.Results.dataPreset;
xTicksBinsize   = p.Results.xTicksBinsize;
graphics        = p.Results.graphics;
saveFig         = p.Results.saveFig;
axh             = p.Results.axh;

zt0 = guessDateTime('0900');    % lights on at 09:00 AM

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data from each session
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% run recursively through the function if several data vars are requested
if iscell(dataPreset)
    fh = figure;
    for idata = 1 : length(dataPreset)
        sb(idata) = subplot(length(dataPreset), 1, idata);
        [expData, tidx, tidxLabels] = sessions_catVarTime('mname', mname,...
            'basepaths', basepaths, 'dataPreset', dataPreset{idata},...
            'graphics', true, 'axh', sb(idata), 'xTicksBinsize', xTicksBinsize);
        if idata < length(dataPreset)
            set(sb(idata), 'xticklabels', {[]})
            xlabel('')
        end
    end
        linkaxes(sb, 'x')
        axis tight
    return
end

varsFile = ["units"; "datInfo"; "session"; string(dataPreset)];
varsName = ["units"; "datInfo"; "session"; string(dataPreset)];

if isempty(basepaths)
    [v, basepaths] = getSessionVars('mname', mname, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""]);
else
    [v, basepaths] = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""]);
end

[~, basenames] = cellfun(@fileparts, basepaths, 'uni', false);
nsessions = length(basepaths);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% select data to concatenate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% params
fs = v(1).session.extracellular.sr;

switch dataPreset
    case 'spec'       
        ch = 1;         % manually change this to switch between spectrograms
        for isession = 1 : nsessions
            if ndims(v(isession).spec.s) == 3
                v(isession).data = squeeze(v(isession).spec.s(:, :, ch))';
            else
                v(isession).data = v(isession).spec.s';
            end
        end
        cfg = as_loadConfig();
        ts = cfg.epochLen;                 % sampling period [s]
        faxis = v(isession).spec.freq;
    
    case 'emg'
        for isession = 1 : nsessions
            filename = fullfile(basepaths{isession},...
                [basenames{isession}, '.sleep_sig.mat']);
            load(filename, 'emg_rms');
            v(isession).data = emg_rms;
        end
        cfg = as_loadConfig();
        ts = cfg.epochLen;                 % sampling period [s]        
        
    case 'sr'
        for isession = 1 : nsessions
            v(isession).data = v(isession).sr.strd;
        end
        ts = v(1).sr.info.binsize;          % sampling period [s]
        grp = 1 : v(1).session.extracellular.nSpikeGroups;
        
    case 'fr'
        % nan pad each session to the max number of units
        nunits = [];
        for isession = 1 : nsessions
            datasz(isession, :) = size(v(isession).fr.strd);
            units = v(isession).units.idx;
            nunits(isession, :) = [sum(units(1, :)), sum(units(2, :))];
            v(isession).rs = v(isession).fr.strd(units(1, :), :);
            v(isession).fs = v(isession).fr.strd(units(2, :), :);
        end
        for isession = 1 : nsessions
            v(isession).data = [v(isession).fr.strd;...
                nan(max(datasz(:, 1)) - datasz(isession, 1),...
                datasz(isession, 2))];
            v(isession).rs = [v(isession).rs;...
                nan(max(nunits(:, 1)) - nunits(isession, 1),...
                datasz(isession, 2))];
            v(isession).fs = [v(isession).fs;...
                nan(max(nunits(:, 2)) - nunits(isession, 2),...
                datasz(isession, 2))];
        end
        ts = v(1).fr.info.binsize;          % sampling period [s]        
        
    case 'ripp'
         for isession = 1 : nsessions
            v(isession).data = v(isession).ripp.rate.rate';
        end
        ts = mode(diff(v(isession).ripp.rate.binedges{1}));                 
        
    otherwise
        DISP('\nno such data preset\n')
end

ncol = size(v(1).data, 1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% time
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% initialize data mat for all sessions based on the time from the first to
% the last session, and the sampling frequency of the variable. assumes the
% recordings are contineous. 
recStart = cellfun(@guessDateTime, basenames, 'uni', true);
expStart = recStart(1) - max([0, diff(timeofday([zt0, recStart(1)]))]);
expEnd = guessDateTime(basenames{end});
expEnd = expEnd + seconds(sum(v(end).datInfo.nsamps) / fs);
expLen = ceil(seconds(expEnd - expStart) / ts); 
expData = nan(expLen, ncol);
expRs = nan(expLen, ncol);
expFs = nan(expLen, ncol);

% initialize
xidx = [];
for isession = 1 : nsessions
    
    % find index to dataMat according to recording start
    recIdx = round(max([1, seconds(recStart(isession) - expStart) / ts]));
    recData = v(isession).data;
    recLen = length(recData);
    
    % insert recording data to experiment data
    expData(recIdx : recIdx + recLen - 1, :) = recData';
    
    if strcmp(dataPreset, 'fr')
        expRs(recIdx : recIdx + recLen - 1, 1 : max(nunits(:, 1))) = v(isession).rs';
        expFs(recIdx : recIdx + recLen - 1, 1 : max(nunits(:, 2))) = v(isession).fs';
    end
    
    % cat block transitions
    xidx = [xidx, cumsum(v(isession).datInfo.nsamps) / fs / ts + recIdx];

end
xtimes = tstamp2time('tstamp', xidx * ts, 'dtstr', expStart);    % times of block transitions

% create timstamps and labels for x-axis
xTicksSamples = xTicksBinsize * 60 * 60;   % [seconds]
zt0idx = round(seconds(diff(timeofday([recStart(1), zt0])))) / ts;
tidx = round([zt0idx : xTicksSamples / ts : expLen]);
tStartLabel = datetime(expStart.Year, expStart.Month, expStart.Day,...
    zt0.Hour, zt0.Minute, zt0.Second);
tidxLabels = string(datestr(datenum(tStartLabel : hours(xTicksBinsize) : expEnd),...
    'HH:MM', 2000));
% add date to x labels once a day
tidxLabels(1 : 24 / xTicksBinsize : end) =...
    string(datestr(datenum(tStartLabel : hours(24) : expEnd),...
    'yymmdd', 2000));
% data for x-axis
xdata = [1 : ts : ceil(seconds(expEnd - expStart))];

% alternative for x labels
% tidxLabels = string(-32 : xTicksBinsize : 130);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if graphics
    
    if isempty(axh)
        fh = figure;
    else
        set(gcf, 'CurrentAxes', axh)
    end
    switch dataPreset
        case {'spec'}
            
            % take a sample of the spectrogram to help initialize the colormap
            showFreqs = find(faxis <= 100);  % freqs to display
            sampleBins = randperm(expLen, round(expLen / 10));
            specSample = reshape(expData(sampleBins, showFreqs), 1, length(sampleBins) * length(showFreqs));
            caxis1 = prctile(specSample, [6 98]);
            
            % plot
            imagesc(xdata, faxis(showFreqs)', expData(:, showFreqs)', caxis1);
            colormap(AccuSleep_colormap());
            axis('xy')
            ylabel('Frequency [Hz]')
        
        case 'emg'            
            % plot
            smoothData = movmean(expData, 33, 1);
            plot(xdata, smoothData);
            colormap(AccuSleep_colormap());
            axis('xy')
            ylabel('Norm. EMG')
            
        case 'sr'
            smoothData = movmean(expData, 13, 1);
            plot(xdata, smoothData(:, grp))
            ylabel('Multi-Unit Firing Rate [Hz]')
            legend(split(num2str(grp)))
            axis tight
            
        case 'fr'
            smoothData = movmean(mean(expRs, 2, 'omitnan'), 13, 1);
            plot(xdata, smoothData, 'LineWidth', 2)
            hold on
            smoothData = movmean(mean(expFs, 2, 'omitnan'), 13, 1);
            plot(xdata, smoothData, 'LineWidth', 2)
            legend({sprintf('RS <= %d', max(nunits(:, 1))),...
                sprintf('FS <= %d', max(nunits(:, 2)))})
            ylabel('Firing Rate [Hz]')
            axis tight
            
        case 'ripp'
            plot(xdata, expData)
            ylabel('Ripple Rate [Hz]')
            axis tight
    end
    
    axis tight
    xticks(tidx * ts)
    xticklabels(tidxLabels)
    xtickangle(45)
    hold on
    %     plot([xidx; xidx] * ts, ylim, '--k', 'HandleVisibility', 'off')
    xlabel('Time [h]')
    
    if saveFig
        mousepath = fileparts(basepaths{1});
        [~, mname] = fileparts(mousepath);
        figpath = fullfile(mousepath, 'graphics');
        figname = sprintf('%s_%s_sessions', mname, dataPreset);
        mkdir(figpath)
        figname = fullfile(figpath, figname);
        export_fig(figname, '-jpg', '-transparent', '-r300')
    end
    
end

end

% EOF
