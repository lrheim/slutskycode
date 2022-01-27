% fr_catSessionsTime

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mname = 'lh96';
forceL = true;
forceA = true;

pcond = ["tempflag"];
ncond = [""];

% load vars from each session
varsFile = ["fr"; "sr"; "cell_metrics"; "datInfo"; "session"];
varsName = ["fr"; "sr"; "cm"; "datInfo"; "session"];
if ~exist('v', 'var') || forceL 
    [v, basepaths] = getSessionVars('mname', mname, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', pcond, 'ncond', ncond);
end
nsessions = length(basepaths);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% decide which data to concatenate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% params
fs = v(1).session.extracellular.sr;
ts = 1 / fs;
ts = v(1).sr.info.binsize;

ncol = size(v(1).sr.strd, 1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% time
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[~, basenames] = cellfun(@fileparts, basepaths, 'uni', false);


% initialize data mat for all sessions based on the time from the first to
% the last session, and the sampling frequency of the variable. assumes the
% recordings are contineous. 
zt0 = guessDateTime('0900');
recStart = cellfun(@guessDateTime, basenames, 'uni', true);
expStart = recStart(1) - max([0, diff(timeofday([zt0, recStart(1)]))]);
expEnd = guessDateTime(basenames{end});
expEnd = expEnd + seconds(sum(v(end).datInfo.nsamps) / fs);
expLen = ceil(seconds(expEnd - expStart) / ts); 
expData = nan(expLen, ncol);

% initialize
tstamps = [];
xidx = [];
for isession = 1 : nsessions
    
    % find index to dataMat according to recording start
    recIdx = round(max([1, seconds(recStart(isession) - expStart) / ts]));
    recData = v(isession).sr.strd;
    recLen = length(recData);
    
    % insert recording data to experiment data
    expData(recIdx : recIdx + recLen - 1, :) = recData';
    
    % cat tstamps and block transitions
    tstamps = [tstamps, v(isession).sr.tstamps / 60 / 60 + recIdx];
    xidx = [xidx, cumsum(v(isession).datInfo.nsamps) / fs / ts + recIdx];
    
end

% create timstamps and labels for x-axis
xTicksBinsize = 12;                              % [hr]
xTicksSamples = xTicksBinsize * 60 * 60 / ts;   % [samples]
zt0idx = round(seconds(diff(timeofday([recStart(1), zt0]))) / ts);
tidx = zt0idx : xTicksSamples : expLen;
tStartLabel = datetime(expStart.Year, expStart.Month, expStart.Day,...
    zt0.Hour, zt0.Minute, zt0.Second);
tidxLabels = datestr(datenum(tStartLabel : hours(xTicksBinsize) : expEnd));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

smoothData = movmean(expData, 13, 1);


fh = figure;
plot(smoothData)
xticks(tidx)
xticklabels(tidxLabels)
hold on
plot([xidx; xidx], ylim, '--k')

legend(split(num2str(1 : 6)))

