function [expData, tidx, tidxLabels] = sessions_catVarTime(varargin)

% concatenates a variable from different sessions. assumes sessions are
% contineous. concatenates according to the time of day extracted from
% basenames. current variables supported are sr and spectrogram.

% INPUT
%   basepaths       cell of chars to recording sessions
%   mname           char of mouse name. if basepaths is empty will get
%                   basepaths from the sessionList.xlsx file
%   graphics        logical {true}
%   saveFig         logical {true}
%   dataPreset      char. variable to cat. can be 'sr', 'spec' or 'both'


% example call
% mname = 'lh96';
% [srData, tidx, tidxLabels] = sessions_catVarTime('mname', mname, 'dataPreset', 'both', 'graphics', false);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addParameter(p, 'basepaths', {}, @iscell);
addParameter(p, 'mname', '', @ischar);
addParameter(p, 'dataPreset', 'sr', @ischar);
addParameter(p, 'graphics', true, @islogical);
addParameter(p, 'saveFig', true, @islogical);

parse(p, varargin{:})
basepaths   = p.Results.basepaths;
mname       = p.Results.mname;
dataPreset  = p.Results.dataPreset;
graphics    = p.Results.graphics;
saveFig     = p.Results.saveFig;
 
xTicksBinsize = 12;             % mark x tick every 12 hr
zt0 = guessDateTime('0900');    % lights on at 09:00 AM

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data from each session
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

varsFile = ["sr"; "fr"; "units"; "datInfo"; "session"];
varsName = ["sr"; "fr"; "units"; "datInfo"; "session"];

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
        for isession = 1 : nsessions
            filename = fullfile(basepaths{isession},...
                [basenames{isession}, '.sleep_sig.mat']);
            load(filename, 'spec');
            v(isession).data = spec';
        end
        cfg = as_loadConfig();
        ts = cfg.epochLen;                 % sampling period [s]
        load(filename, 'spec_freq');
        faxis = spec_freq;
        
    case {'sr', 'both'}
        for isession = 1 : nsessions
            v(isession).data = v(isession).sr.strd;
        end
        ts = v(1).sr.info.binsize;          % sampling period [s]
        grp = 1 : v(1).session.extracellular.nSpikeGroups;
        
    case 'fr'
        % nan pad each session to the max number of units
        units = [];
        for isession = 1 : nsessions
            datasz(isession, :) = size(v(isession).fr.strd);
            v(isession).data = v(isession).fr.strd(units.idx(1, :));
            units = v(isession).units.idx;
        end
        for isession = 1 : nsessions
            v(isession).data = [v(isession).data;...
                nan(max(datasz(:, 1)) - datasz(isession, 1),...
                datasz(isession, 2))];
        end
        ts = v(1).fr.info.binsize;          % sampling period [s]        
        units = logical(units);
        
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

% initialize
xidx = [];
for isession = 1 : nsessions
    
    % find index to dataMat according to recording start
    recIdx = round(max([1, seconds(recStart(isession) - expStart) / ts]));
    recData = v(isession).data;
    recLen = length(recData);
    
    % insert recording data to experiment data
    expData(recIdx : recIdx + recLen - 1, :) = recData';
    
    % cat block transitions
    xidx = [xidx, cumsum(v(isession).datInfo.nsamps) / fs / ts + recIdx];

end
xtimes = tstamp2time('tstamp', xidx * ts, 'dtstr', expStart);    % times of block transitions

% create timstamps and labels for x-axis
xTicksSamples = xTicksBinsize * 60 * 60 / ts;   % [samples]
zt0idx = round(seconds(diff(timeofday([recStart(1), zt0]))) / ts);
tidx = zt0idx : xTicksSamples : expLen;
tStartLabel = datetime(expStart.Year, expStart.Month, expStart.Day,...
    zt0.Hour, zt0.Minute, zt0.Second);
tidxLabels = datestr(datenum(tStartLabel : hours(xTicksBinsize) : expEnd),...
    'yymmdd_HH:MM', 2000);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if graphics
    
    fh = figure;
    switch dataPreset
        case 'spec'
            
            % take a sample of the spectrogram to help initialize the colormap
            showFreqs = find(faxis <= 15);  % freqs to display
            sampleBins = randperm(expLen, round(expLen / 10));
            specSample = reshape(expData(sampleBins, showFreqs), 1, length(sampleBins) * length(showFreqs));
            caxis1 = prctile(specSample, [6 98]);
            
            % plot
            imagesc([1 : expLen], faxis(showFreqs)', expData(:, showFreqs)', caxis1);
            colormap(AccuSleep_colormap());
            axis('xy')
            ylabel('Frequency [Hz]')
            
        case {'sr', 'both'}
            smoothData = movmean(expData, 13, 1);
            plot(smoothData(:, grp))
            ylabel('Multi-Unit Firing Rate [Hz]')
            legend(split(num2str(grp)))
            
        case 'fr'
            smoothData = movmean(expData, 13, 1);
            plot(smoothData)
    end
    
    xticks(tidx)
    xticklabels(tidxLabels)
    hold on
    plot([xidx; xidx], ylim, '--k', 'HandleVisibility', 'off')
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create figure of both vars
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~strcmp(dataPreset, 'both')
    return
else
    srData = expData;
    [specData, ~, ~] = sessions_catVarTime('mname', mname,...
        'dataPreset', 'spec', 'graphics', true);
    load(fullfile(basepaths{isession},...
        [basenames{isession}, '.sleep_sig.mat']), 'spec_freq');
    faxis = spec_freq;
end

% select specific tidx to plot
sidx = [11, 25];
xtimes(sidx)
sxidx = xidx(sidx);

% plot
fh = figure;

subplot(2, 1, 1)
smoothData = movmean(srData, 13, 1);
plot(smoothData)
ylabel('Multi-Unit Firing Rate [Hz]')
xticks(tidx)
xticklabels(tidxLabels)
hold on
plot([sxidx; sxidx], ylim, '--k', 'LineWidth', 2)
xlabel('Time')
axis tight
legend(split(num2str(1 : size(smoothData, 2))))

% spec
subplot(2, 1, 2)
showFreqs = find(faxis <= 15);  % freqs to display
sampleBins = randperm(expLen, round(expLen / 10));
specSample = reshape(specData(sampleBins, showFreqs), 1, length(sampleBins) * length(showFreqs));
caxis1 = prctile(specSample, [6 98]);
imagesc([1 : expLen], faxis(showFreqs)', specData(:, showFreqs)', caxis1);
colormap(AccuSleep_colormap());
axis('xy')
ylabel('Frequency [Hz]')
xticks(tidx)
xticklabels(tidxLabels)
hold on
plot([sxidx; sxidx], ylim, '--y', 'LineWidth', 2)
xlabel('Time')

saveFig = false;
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

% EOF