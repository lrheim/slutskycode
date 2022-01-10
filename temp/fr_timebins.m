function frBins = fr_timebins(varargin)

% INPUT:
%   basepath        string. path to recording folder {pwd}
%   timebins        numeric. timebins to calc psd
%                   in relation to these poitns [sec].  
%   saveVar         logical. save ss var {true}
%   forceA          logical. reanalyze recordings even if ss struct
%                   exists (false)
%   graphics        logical. plot confusion chart and state separation {true}
%
% DEPENDENCIES
%
% TO DO LIST
%
% 07 jan 22 LH

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'timebins', [0 Inf], @isnumeric);
addOptional(p, 'tbins_txt', []);
addOptional(p, 'saveVar', true, @islogical);
addOptional(p, 'forceA', false, @islogical);
addOptional(p, 'graphics', true, @islogical);

parse(p, varargin{:})
basepath        = p.Results.basepath;
timebins        = p.Results.timebins;
tbins_txt       = p.Results.tbins_txt;
saveVar         = p.Results.saveVar;
forceA          = p.Results.forceA;
graphics        = p.Results.graphics;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load vars from each session
varsFile = ["fr"; "sr"; "spikes"; "st_metrics"; "swv_metrics";...
    "cell_metrics"; "AccuSleep_states"; "ripp.mat"; "datInfo"; "session"];
varsName = ["fr"; "sr"; "spikes"; "st"; "swv"; "cm"; "ss"; "ripp";...
    "datInfo"; "session"];
if ~exist('varArray', 'var') || forceL
    v = getSessionVars('basepaths', {basepath}, 'varsFile', varsFile,...
        'varsName', varsName);
end

% file
cd(basepath)
[~, basename] = fileparts(basepath);
frfile = fullfile(basepath, [basename, '.fr_bins.mat']);

nbins = length(timebins);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% firing rate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% check if already analyzed
if exist(frfile, 'file') && ~forceA
    load(frfile)
else
    for iwin = 1 : nbins
        
        frBins(iwin) = firingRate(v.spikes.times,...
            'basepath', basepath, 'graphics', false,...
            'binsize', 60, 'saveVar', false, 'smet', 'GK', 'winBL',...
            [0, Inf], 'winCalc', timebins(iwin, :), 'forceA', true);
        
    end
end

if saveVar
    save(frfile, 'frBins')
end

% re-organize vars of interest
frBoundries = [0.01, Inf; 0.01, Inf];
% arrange
ridx = [1, 4];
% units
clear units
units(1, :) = selectUnits(v.spikes, v.cm,...
    v.fr, 1, [], frBoundries, 'pyr');
units(2, :) = selectUnits(v.spikes, v.cm,...
    v.fr, 1, [], frBoundries, 'int');

for iwin = 1 : nbins
    sratio(iwin, :) = squeeze(frBins(iwin).states.ratio(ridx(1), ridx(2), :));    
    mfrWake(iwin, :) = mean(frBins(iwin).states.fr{1}, 2);
    mfrNrem(iwin, :) = mean(frBins(iwin).states.fr{4}, 2);
        
end

yLimit = [min([sratio], [], 'all'), max([sratio], [], 'all')];
tbins_txt = {'0-3ZT', '3-6ZT', '6-9ZT', '9-12ZT',...
    '12-15ZT', '15-18ZT', '18-21ZT', '21-24ZT'};
        
% graphics
fh = figure;
cfg = as_loadConfig();

subplot(3, 2, 1)
dataMat = mfrWake(:, units(1, :));
plot_boxMean('dataMat', dataMat', 'clr', cfg.colors{1})
ylabel('MFR WAKE')
subtitle('RS units')
xticklabels(tbins_txt)

subplot(3, 2, 2)
dataMat = mfrWake(:, units(2, :));
plot_boxMean('dataMat', dataMat', 'clr', cfg.colors{1})
ylabel('MFR WAKE')
subtitle('FS units')
xticklabels(tbins_txt)

subplot(3, 2, 3)
dataMat = mfrNrem(:, units(1, :));
plot_boxMean('dataMat', dataMat', 'clr', cfg.colors{4})
ylabel('MFR NREM')
xticklabels(tbins_txt)

subplot(3, 2, 4)
dataMat = mfrNrem(:, units(2, :));
plot_boxMean('dataMat', dataMat', 'clr', cfg.colors{4})
ylabel('MFR NREM')
xticklabels(tbins_txt)

subplot(3, 2, 5)
dataMat = sratio(:, units(1, :));
plot_boxMean('dataMat', dataMat', 'clr', 'k')
ylabel({'WAKE - NREM /', 'WAKE + NREM'})
ylim(yLimit)
xticklabels(tbins_txt)

subplot(3, 2, 6)
dataMat = sratio(:, units(2, :));
plot_boxMean('dataMat', dataMat', 'clr', 'k')
ylabel({'WAKE - NREM /', 'WAKE + NREM'})
ylim(yLimit)
xticklabels(tbins_txt)

sgtitle(basename)






