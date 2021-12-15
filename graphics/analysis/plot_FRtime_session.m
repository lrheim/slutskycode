
function plot_FRtime_session(basepath)

% plots firing rate of mu (sr) and su (pyr and int) across time for a
% single session (according to basepath).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[~, basename] = fileparts(basepath);
cd(basepath)
guessDateTime(basename)

grp = [1 : 4];                  % which tetrodes to plot
suFlag = 1;                     % plot only su or all units
saveFig = false;
% include only units with fr greater / lower than. 1st row RS 2nd row FS
frBoundries = [0.2 Inf; 0.2 Inf];  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load data
[varArray, ~, mousepath] = getSessionVars('dirnames', string(basename));
assignVars(varArray, 1)

if ~isempty(fr)
    if length(fr.strd) ~= length(sr.strd)
        warning('check length of mu and su firing rate')
    end
end

% x axis in hr
ts = fr.binsize;
xidx = [1 : length(fr.strd)] / ts;

% idx of block tranisition (dashed lines)
if ~isempty(datInfo)
    if ~isfield('datInfo', 'fs')
        datInfo.fs = 20000;
    end
    csum = cumsum(datInfo.nsamps) / datInfo.fs / 60 / 60;
    tidx = csum(:);
else
    tidx = 0;
end

% units
clear units
units(1, :) = selectUnits(spikes, cm, fr, suFlag, grp, frBoundries, 'pyr');
units(2, :) = selectUnits(spikes, cm, fr, suFlag, grp, frBoundries, 'int');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plot
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fh = figure;
title(basename)

if ~isempty(fr)
    yLimit = ceil([0 max(max(sr.strd))]);
    hold on
    plot(xidx, sr.strd')
    plot([tidx tidx], yLimit, '--k')
    axis tight
    set(gca, 'box', 'off');
    ylabel('Multi-unit firing rate [Hz]')
    lgh = legend(split(num2str(grp)));
    figname = 'sr_time';
    
else
    
    % ---------------------------------------------------------------------
    % individual cells on a log scale    
    subplot(2, 1, 1)
    hold on
    
    % rs 
    ph = plot(xidx, fr.strd(units(1, :), :), 'b', 'LineWidth', 2);
    alphaIdx = linspace(1, 0.3, length(ph));
    for iunit = 1 : length(ph)
            ph(iunit).Color(4) = alphaIdx(iunit);
    end
    
    % fs
    ph = plot(xidx, fr.strd(units(2, :), :), 'r', 'LineWidth', 2);
    alphaIdx = linspace(1, 0.3, length(ph));
    for iunit = 1 : length(ph)
            ph(iunit).Color(4) = alphaIdx(iunit);
    end
    
    plot([tidx tidx], ylim, '--k')
    set(gca, 'YScale', 'log')
    axis tight
    xlabel('Time [h]')
    ylabel('Single unit firing rate [Hz]')
    set(gca, 'box', 'off')
    linkaxes([sb1, sb2], 'x')
    
    % ---------------------------------------------------------------------
    % mean per cell class on a linear scale 
    subplot(2, 1, 2)
    yLimit = [0 ceil(max(mean(fr.strd(units(2, :), :), 'omitnan')))];
    hold on
    plot(xidx, mean(fr.strd(units(1, :), :), 'omitnan'), 'b', 'LineWidth', 2)
    plot(xidx, mean(fr.strd(units(2, :), :), 'omitnan'), 'r', 'LineWidth', 2)
    plot([tidx tidx], yLimit, '--k')
    axis tight
    xlabel('Time [h]')
    ylabel('Single unit firing rate [Hz]')
    set(gca, 'box', 'off')
    linkaxes([sb1, sb2], 'x')
    
    legend(sprintf('RS ~= %d su', sum(units(1, :))),...
        sprintf('FS ~= %d su', sum(units(2, :))));
    figname = 'fr_time';

end

if saveFig
    figpath = fullfile(pwd, 'graphics');
    mkdir(figpath)
    figname = fullfile(figpath, figname);
    export_fig(figname, '-tif', '-transparent', '-r300')
end

end

% EOF