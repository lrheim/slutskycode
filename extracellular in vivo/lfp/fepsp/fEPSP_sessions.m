% fEPSP_sessions

% organizes and plots fepsp from multiple sessions. gets structs and
% transforms them to matrices of vars (e.g. amp and wv) vs. time
% (sessions). rubust to missing sessions (replaced by nan) and allows for
% different stim intensities between sessions. compensates if arrays are
% not sorted (though fEPSPfromOE should sort by intensity)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fr_sessions

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
forceL = true;
forceA = false;

basepath = 'G:\Data\Processed\lh58\fepsp';
dirnames = ["lh58_200915_100905";...
    "lh58_200915_110952";...
    "lh58_200915_170935";...
    "lh58_200916_100928";...
    "lh58_200916_120928";...
    "lh58_200916_160953";...
    "lh58_200917_100922";...
    "lh58_200917_170931"];
clear dirnames

% should allow user to input varName or columnn index
colName = 'Session';                    % column name in xls sheet where dirnames exist
% string array of variables to load
vars = ["session.mat";...
    "fepsp"];      
% column name of logical values for each session. only if true than session
% will be loaded. can be a string array and than all conditions must be
% met.
pcond = ["fepsp"; "tempFlag"];     
% pcond = [];
% same but imposes a negative condition)
ncond = ["manCur"];                      
sessionlist = 'sessionList.xlsx';       % must include extension
fs = 1250;                             % can also be loaded from datInfo

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get directory paths
if exist('dirnames', 'var') && isstring(dirnames)
    % ALT 1: user input dirnames
    dirnames = dirnames;
elseif ischar(sessionlist) && contains(sessionlist, 'xlsx')
    % ALT 2: get dirnames from xlsx file
    sessionInfo = readtable(fullfile(basepath, sessionlist));
    icol = strcmp(sessionInfo.Properties.VariableNames, colName);
    dirnames = string(table2cell(sessionInfo(:, icol)));
    % check dirnames meet conditions
    clear irow iicol
    irow = ones(length(dirnames), 1);
    for i = 1 : length(pcond)
        iicol(i) = find(strcmp(sessionInfo.Properties.VariableNames, char(pcond(i))));
        irow = irow & sessionInfo{:, iicol(i)} == 1;
    end
    for i = 1 : length(ncond)
        iicol(i) = find(strcmp(sessionInfo.Properties.VariableNames, char(ncond(i))));
        irow = irow & sessionInfo{:, iicol(i)} ~= 1;
    end
    dirnames = dirnames(irow);
    dirnames(strlength(dirnames) < 1) = [];
end

nsessions = length(dirnames);

% load files
if forceL   
    d = cell(length(dirnames), length(vars));
    for i = 1 : nsessions
        filepath = char(fullfile(basepath, dirnames(i)));
        if ~exist(filepath, 'dir')
            warning('%s does not exist, skipping...', filepath)
            continue
        end
        cd(filepath)
        
        for ii = 1 : length(vars)           
            filename = dir(['*', vars{ii}, '*']);
            if length(filename) == 1
                d{i, ii} = load(filename.name);
            else
                warning('no %s file in %s, skipping', vars{ii}, filepath)
            end
        end
    end
end

% session info
session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'force', true, 'saveVar', true);
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;
ngrp = length(spkgrp);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% analyze data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if forceA
    for i = 1 : nsessions
        close all        
        
        % file
        filepath = char(fullfile(basepath, dirnames(i)));
        cd(filepath)
        [~, basename] = fileparts(filepath);
               
        % fepsp
        intens = [40 60 80 100 150 200];
        fepsp = fEPSPfromDat('basepath', filepath, 'fname', '', 'nchans', nchans,...
            'spkgrp', spkgrp, 'intens', intens, 'concat', false, 'saveVar', true,...
            'force', true, 'extension', 'dat', 'recSystem', 'oe',...
            'protocol', 'io', 'graphics', false);        
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rearrange data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% intensities throughout sessions
intens = [];
for i = 1 : nsessions
    if isempty(d{i, 2})
        continue
    end
    fepsp = d{i, 2}.fepsp;
    intens = sort(unique([intens, fepsp.intens]));
end

% ampmat    3d mat of amplitudes; tetrode x intensity x session. data will
%           be extrapolated to intensities not recorded in session.
% wvmat     3d mat of average waveforms; tetrode x session x sample
%           for 1 selected intensity. 
% ampcell   array of amplitudes for selected intensity. each cell
%           contains amps of all traces. if itensity not recorded will be
%           extrapolated.
ampmat = nan(ngrp, length(intens), nsessions);
wvmat = nan(ngrp, nsessions, size(fepsp.wvsnip, 3));
ampcell = cell(1, nsessions);
si = 150;        % selected intensity [uA]
grp = 3;        % selected tetrode
for i = 1 : nsessions
    fepsp = d{i, 2}.fepsp;
    sintens = sort(fepsp.intens);
    [~, ia] = intersect(sintens, si);
    [~, ib] = intersect(intens, si);
    ampmat(:, :, i) = [interp1(sintens, fepsp.amp(:, :)', intens, 'linear', 'extrap')]';
    if ~isempty(ia)
        for ii = 1 : ngrp
            wvmat(ii, i, :) = fepsp.wvsnip(ii, ia, :);
            ampcell{i} = fepsp.ampcell{grp, ia};
        end
    else
        ampcell{i} = ampmat(grp, ib, i);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
close all
set(groot,'defaultAxesTickLabelInterpreter','none');  
set(groot,'defaulttextinterpreter','latex');
set(groot,'defaultLegendInterpreter','latex');

pathPieces = regexp(dirnames(:), '_', 'split'); % Assumes file structure: animal/session/
sessionDate = [pathPieces{:}];
sessionDate = sessionDate(2 : 3 : end);

% one figure per intensity across sessions
p = 0;
if p
    for i = 1 : length(intens)
        figure
        plot(squeeze(ampmat(:, i, :))', 'LineWidth', 2)
        xlabel('Session')
        ylabel('Amplitude [mV]')
        title(sprintf('Stim Intensity %d uA', intens(i)))
        legend(strsplit(num2str(1 : ngrp)))
        xticks(1 : nsessions)
        xticklabels(sessionDate)
        xtickangle(45)
        box off
    end
end

% waveform and box plot of amplitudes across sessions for selected
% intensity and tetrode
p = 1;
if p
    figure
    subplot(2, 1, 1)
    tstamps = [1 : size(wvmat, 3)] / fs * 1000;
    plot(tstamps, squeeze(wvmat(grp, :, :)))
    xlabel('Time [ms]')
    ylabel('Voltage [V]')
    legend(sessionDate)
    box off
    
    subplot(2, 1, 2)
    ampmat = cell2nanmat(ampcell);
    boxplot(ampmat, 'PlotStyle', 'traditional')
    xticks(1 : nsessions)
    xticklabels(sessionDate)
    xtickangle(45)
    xlabel('Session')
    ylabel('Amplidute [mV]')
    box off
    
    suptitle(['T#' num2str(grp) ' @ ' num2str(si) 'uA'])
end

% io across sessions, one figure per tetrode
p = 1;
grp = 3;
if p
    for i = grp
        figure
        for ii = 1 : nsessions
            fepsp = d{ii, 2}.fepsp;
            plot(sort(fepsp.intens), fepsp.amp(i, :))
            hold on
        end
        axis tight
        xlabel('Intensity [uA]')
        ylabel('Amplitude [mV]')
        title(sprintf('T%d', i))
        legend(sessionDate)
        box off
    end
end

% one figure per tetrode
p = 1;
if p
    for i = 1 : ngrp
        figure
        plot(squeeze(ampmat(i, :, :))', 'LineWidth', 2)
        axis tight
        y = ylim;
        ylim([0 y(2)])
        xticks(1 : nsessions)
        xlabel('Session')
        ylabel('Amplitude [mV]')
        title(sprintf('T%d', i))
        legend(split(num2str(intens)))
        box off
    end
end

% % waveform across sessions
% p = 1;
% ss = [4, 8, 16, 24];    % selected sessions
% sg = [1, 7];
% if p
%     for i = sg
%         figure
%         plot(tstamps, squeeze(wvmat(i, ss, :))')
%         axis tight
%         xlabel('Time [ms]')
%         ylabel('Amplitude [mV]')
%         title(sprintf('T%d', i))
%         box off
%         legend(split(dirnames(ss)), 'Interpreter', 'none');
%     end
% end

% waveform across time within session
p = 0;
sg = 7;         % selected group
si = 250;       % selected intensity
ss = 1;         % selected session
if p
    for i = sg
        figure
        suptitle(sprintf('T%d @ %s', i, dirnames(ss)))
        sintens = f{ss}.intens;
        [~, ib] = intersect(sintens, si);
        swv = squeeze(mean(f{ss}.wv{i, ib}, 1));
        samp = f{ss}.ampcell{i, ib};
        
        subplot(1 ,2 ,1)
        plot(tstamps, swv)
        axis tight
        xlabel('Time [ms]')
        ylabel('Amplitude [mV]')
        legend
        box off
        
        subplot(1, 2, 2)
        plot(1 : length(samp), samp)
        xlabel('Stim #')
        ylabel('Amplitude [mV]')
        y = ylim;
        ylim([0 y(2)])
        box off
    end
end

% comparison night and day
% amp during night (even) devided by values in day (odd).
% tetrodes x intensities x days. 
p = 1;
sg = [1, 4 : 8];    % excluded tetrodes not in ca1. 
si = [200, 250, 300];    % reliable intensities
[~, ib] = intersect(intens, si);

% night = ampmat(sg, ib, 2 : 2 : end);
% night = mean(night(:, :, [1 : 3]), 3);
% day = ampmat(sg, ib, 1 : 2 : end);
% day = mean(day(:, :, [1 : 3]), 3);
% night ./ day
% night = ampmat(sg, ib, 2 : 2 : end);
% night = mean(night(:, :, [5 : 10]), 3);
% day = ampmat(sg, ib, 1 : 2 : end);
% day = mean(day(:, :, [5 : 10]), 3);
% night ./ day
% night = ampmat(sg, ib, 2 : 2 : end);
% night = mean(night(:, :, [12 : 13]), 3);
% day = ampmat(sg, ib, 1 : 2 : end);
% day = mean(day(:, :, [12 : 13]), 3);
% night ./ day

ndmat = ampmat(sg, ib, 2 : 2 : end) ./  ampmat(sg, ib, 1 : 2 : end);
if p
    figure
    [~, ib] = intersect(intens, si);
    plot(squeeze(mean(ndmat(:, :, :), 2))', 'LineWidth', 2)
    hold on
    plot([1 size(ndmat, 3)], [1 1], '--k')
    axis tight
    y = ylim;
    ylim([0 y(2)])
    xlabel('Time [days]')
    ylabel('Ratio night / day')
    legend(split(num2str(sg)))
    title(sprintf('night / day @%d uA', intens(ib)))
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% to prism
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
squeeze(ampmat(7, :, :));
squeeze(wvmat(7, :, :));

squeeze(mean(mean(ndmat(:, :, 1 : 3), 2), 1))
squeeze(mean(mean(ndmat(:, :, 5 : 10), 2), 1))
squeeze(mean(mean(ndmat(:, :, 12 : 13), 2), 1))

plot(squeeze(mean(ampmat([1, 4 : 8], [2 : 6], :), 1))')