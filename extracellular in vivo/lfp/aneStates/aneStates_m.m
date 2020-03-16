function [bs, iis, ep] = aneStates_m(varargin)

% analyze anesthesia states of one mouse. for tetrodes omit the
% basename argument and direct to basepath
%
% INPUT
%   ch          vector. channel/s to analyze.
%   binsize     scalar [s]. applied to bsr, iis rate, and spec band
%   smf         smooth factor [bins]. applied to bsr, iis rate, and spec band
%   basepath    string. recording session path {pwd}
%   basename    string. mouse basename. if empty extracted from basepath
%   graphics    logical. plot figure {1}
%   saveVar     logical. save variable {1}
%   saveFig     logical. save figure {1}
%   forceA      logical {0}. force analysis even if .mat exists
%   forceL      logical {0}. force load lfp even if .mat exists
%
% OUTPUT
%   bs          struct (see getBS.m)
%   iis         struct (see getIIS.m)
%   spec        struct with fields:
%       dband   normalized power in the delta band (1-4 Hz)
%       sband   normalized power in the sigma band (12-20 Hz)
%       tband   timestamps for normalized power
%
% TO DO LIST
%       #
%
% CALLS
%       fetLFP
%       getBS
%       getIIS
%       specBand
%       binary2epochs
%
% EXAMPLE
%       [bs, iis, ep] = aneStates_m('ch', 1, 'basepath', basepath,...
%        'basename', basename, 'graphics', graphics, 'saveVar', saveVar,...
%        'saveFig', saveFig, 'forceA', forceA, 'binsize', 30, 'smf', 6);
% 
% 21 jan 20 LH

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

p = inputParser;
addParameter(p, 'ch', 1, @isvector);
addParameter(p, 'binsize', 30, @isnumeric);
addParameter(p, 'smf', 7, @isnumeric);
addParameter(p, 'basepath', pwd, @isstr);
addParameter(p, 'basename', [], @isstr);
addParameter(p, 'graphics', true, @islogical)
addParameter(p, 'saveVar', true, @islogical);
addParameter(p, 'saveFig', true, @islogical);
addParameter(p, 'forceA', false, @islogical);
addParameter(p, 'forceL', false, @islogical);

parse(p, varargin{:})
ch = p.Results.ch;
binsize = p.Results.binsize;
smf = p.Results.smf;
basepath = p.Results.basepath;
basename = p.Results.basename;
graphics = p.Results.graphics;
saveVar = p.Results.saveVar;
saveFig = p.Results.saveFig;
forceA = p.Results.forceA;
forceL = p.Results.forceL;

if isempty(basename)
    [~, basename] = fileparts(basepath);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lfp data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
interval = [1 57];
lfp = getLFP('basepath', basepath, 'ch', ch, 'chavg', {},...
    'fs', 1250, 'interval', interval, 'extension', 'wcp', 'pli', true,...
    'savevar', true, 'force', forceL, 'basename', basename);
sig = double(lfp.data(:, ch));
fs = lfp.fs;
binsize = (2 ^ nextpow2(binsize * fs));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% burst suppression
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
vars = {'std', 'max', 'pc1'};
bs = getBS('sig', sig, 'fs', fs, 'basepath', basepath, 'graphics', true,...
    'saveVar', saveVar, 'binsize', 0.5, 'BSRbinsize', binsize, 'smf', smf,...
    'clustmet', 'gmm', 'vars', vars, 'basename', basename,...
    'saveFig', saveFig, 'forceA', forceA, 'vis', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% iis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% thr during suppression
thr = [0 mean(sig(~bs.binary(1 : 15 * fs * 60)))...
    + 15 * std(sig(~bs.binary(1 : 15 * fs * 60)))];
if isnan(thr(2))
    thr(2) = 0.5;
end
marg = 0.05;
iis = getIIS('sig', sig, 'fs', fs, 'basepath', basepath,...
    'graphics', true, 'saveVar', saveVar, 'binsize', binsize,...
    'marg', marg, 'basename', basename, 'thr', thr, 'smf', 7,...
    'saveFig', saveFig, 'forceA', forceA, 'spkw', false, 'vis', true);
wvstamps = linspace(-marg, marg, floor(marg * fs) * 2 + 1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% burst suppression after IIS filteration
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% if isfield(iis, 'filtered') && size(iis.wv, 1) > 50
%     bs = getBS('sig', iis.filtered, 'fs', fs, 'basepath', basepath, 'graphics', false,...
%         'saveVar', saveVar, 'binsize', 0.5, 'BSRbinsize', binsize, 'smf', smf,...
%         'clustmet', 'gmm', 'vars', vars, 'basename', basename,...
%         'saveFig', saveFig, 'forceA', forceA, 'vis', false);
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% anesthesia states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spectrum power bands
[ep.dband, tband] = specBand('sig', sig, 'graphics', false,...
    'band', [1 4], 'binsize', binsize, 'smf', smf, 'normband', true);

% episodes of deep anesthesia
vec = [bs.bsr > 0.3 & bs.bsr < 0.8];
ep.deep_stamps = binary2epochs('vec', vec, 'minDur', 1, 'interDur', 1);

% bins to samples
ep.deep_stamps = bs.cents(ep.deep_stamps);
if ~isempty(ep.deep_stamps)
    if ep.deep_stamps(1) == bs.cents(1)
        ep.deep_stamps(1) = 1;
    end
    if ep.deep_stamps(end) == bs.cents(end)
        ep.deep_stamps(end) = length(sig);
    end
end

idx = [];
idx2 = [];
for j = 1 : size(ep.deep_stamps, 1)
    % iis within epochs
    idx = [idx; find(iis.peakPos > ep.deep_stamps(j, 1) &...
        iis.peakPos < ep.deep_stamps(j, 2))];
    % mean delta within epochs
    idx2 = [idx2, find(iis.cents >= ep.deep_stamps(j, 1) &...
        iis.cents <= ep.deep_stamps(j, 2))];
end
ep.deep_nspks = length(idx);
ep.deep_delta = mean(ep.dband(idx2));
wv = iis.wv(idx, :);

% episodes of surgical anesthesia
vec = [bs.bsr < 0.3 & ep.dband > 0.5];
ep.sur_stamps = binary2epochs('vec', vec, 'minDur', 1, 'interDur', 1);
ep.sur_stamps = bs.cents(ep.sur_stamps);
if ~isempty(ep.sur_stamps)
    if ep.sur_stamps(1) == bs.cents(1)
        ep.sur_stamps(1) = 1;
    end
    if ep.sur_stamps(end) == bs.cents(end)
        ep.sur_stamps(end) = length(sig);
    end
end
idx = [];
idx2 = [];
for j = 1 : size(ep.sur_stamps, 1)
    idx = [idx; find(iis.peakPos > ep.sur_stamps(j, 1) &...
        iis.peakPos < ep.sur_stamps(j, 2))];   
    idx2 = [idx2, find(iis.cents >= ep.sur_stamps(j, 1) &...
        iis.cents <= ep.sur_stamps(j, 2))];
end
ep.sur_delta = mean(ep.dband(idx2));
ep.sur_nspks = length(idx);

% episode and recording duration
ep.surDur = sum(diff(ep.sur_stamps, [], 2));
ep.deepDur = sum(diff(ep.deep_stamps, [], 2));
ep.recDur = length(sig);

% normalize nspks to duration
ep.sur_nspks = ep.sur_nspks / (ep.surDur / fs / 60);
ep.deep_nspks = ep.deep_nspks / (ep.deepDur / fs / 60);
ep.nspks = size(iis.wv, 1) / (ep.recDur / fs / 60);

save([basename '.ep.mat'], 'ep')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% idx for zoomin 
minmarg = 1.5;
midsig = 10;
idx = round((midsig - minmarg) * fs * 60 : (midsig + minmarg) * fs * 60);

if graphics    
    fh = figure('Visible', 'off');
    set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
    suptitle(basename)
    
    % spectrogram
    sb1 = subplot(4, 2, 1 : 2);
    specBand('sig', sig, 'graphics', true, 'binsize',...,
        (2 ^ nextpow2(5 * fs)), 'smf', smf, 'normband', true);
    set(gca, 'TickLength', [0 0], 'XTickLabel', [],...
        'Color', 'none', 'XColor', 'none')
    ylim([0 100])
    title('')
    
    % bsr and delta
    sb2 = subplot(4, 2, 3 : 4);
    plot(bs.cents / fs / 60, bs.bsr, 'k', 'LineWidth', 1)
    hold on
    plot(bs.cents / fs / 60, ep.dband, 'b', 'LineWidth', 1)
    ylim([0 1])
    Y = ylim;
    set(gca, 'TickLength', [0 0], 'ytick', [0 1], 'XTickLabel', [],...
        'Color', 'none', 'XColor', 'none')
    box off
    legend({'BSR', 'Delta'})
    if ~isempty(ep.deep_stamps)
        fill([ep.deep_stamps fliplr(ep.deep_stamps)]' / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
            'b', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
    end
    if ~isempty(ep.sur_stamps)
        fill([ep.sur_stamps fliplr(ep.sur_stamps)]' / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
            'g', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
    end
    axis tight

    % raw
    sb3 = subplot(4, 2, 5 : 6);
    plot(lfp.timestamps / 60, sig, 'k', 'LineWidth', 1)
    hold on
    ylim([-1 3]);
    set(gca, 'TickLength', [0 0], 'ytick', [-1 3],...
        'Color', 'none')
    box off
    ylabel('LFP [mV]')
    Y = ylim;
    idx3 = [idx(1) idx(end)] / fs / 60;
    fill([idx3 fliplr(idx3)]', [Y(1) Y(1) Y(2) Y(2)],...
        'r', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
        axis tight
    xlabel('Time [m]')
    
    % zoom in
    subplot(4, 2, 8);
    idx2 = iis.peakPos > idx(1) & iis.peakPos < idx(end);
    plot(lfp.timestamps(idx) / 60, sig(idx), 'k')
    axis tight
    hold on
    x = xlim;
    plot(x, [iis.thr(2) iis.thr(2)], '--r')
    scatter(iis.peakPos(idx2) / fs / 60,...
        iis.peakPower(idx2), '*');
    bsstamps = RestrictInts(bs.stamps, [idx(1) idx(end)]);
    Y = ylim;
    if ~isempty(bsstamps)
        fill([bsstamps fliplr(bsstamps)]' / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
            'k', 'FaceAlpha', 0.25,  'EdgeAlpha', 0);
    end
    ylabel('Voltage [mV]')
    xlabel('Time [m]')
    xticks(idx3)
    set(gca, 'TickLength', [0 0])
    box off
    title('IIS')    
    
    % iis waveforms
    if ~isempty(iis.wv)
    subplot(4, 2, 7)
    plot(wvstamps * 1000, iis.wv)
    ylabel('Voltage [mV]')
    xlabel('Time [ms]')
    axis tight
    xticks([-marg, 0, marg] * 1000);
    set(gca, 'TickLength', [0 0])
    box off
    title('IIS waveform')
    
    % mean + std waveform
    axes('Position',[.1315 .11 .13 .08])
    box on
    stdshade(iis.wv, 0.5, 'k', wvstamps)
    axis tight
    set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
        'XColor', 'none', 'YColor', 'none', 'Color', 'none')
    title(sprintf('n = %d', size(iis.wv, 1)));
    box off
    end
    
    linkaxes([sb1, sb2, sb3], 'x');

    if saveFig
        figname = [basename];
        export_fig(figname, '-tif', '-transparent')
        % savePdf(figname, basepath, ff)
    end
    
end   
end

