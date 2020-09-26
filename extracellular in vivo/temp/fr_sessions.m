% fr_sessions

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
forceL = false;
forceA = false;

% should allow user to input varName or columnn index
colName = 'Session';                    % column name in xls sheet where dirnames exist
% string array of variables to load
vars = ["session.mat";...
    "cell_metrics.cellinfo";...
    "spikes.cellinfo";...
    "SleepState.states";....
    "fr.mat";...
    "datInfo"];
% column name of logical values for each session. only if true than session
% will be loaded. can be a string array and than all conditions must be
% met.
pcond = ["tempFlag"];
% pcond = [];
% same but imposes a negative condition)
ncond = ["fix"];
ncond = ["fepsp"];
sessionlist = 'sessionList.xlsx';       % must include extension
fs = 20000;                             % can also be loaded from datInfo

basepath = 'D:\VMs\shared\lh58';
% dirnames = ["lh58_200831_080808";...
%     "lh58_200901_080917";...
%     "lh58_200903_080936";...
%     "lh58_200905_080948";...
%     "lh58_200906_090914"];
% clear dirnames

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
pathPieces = regexp(dirnames(:), '_', 'split'); % assumes filename structure: animal_date_time
sessionDate = [pathPieces{:}];
sessionDate = sessionDate(2 : 3 : end);

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
        
        % session info
        session = CE_sessionTemplate(pwd, 'viaGUI', false,...
            'force', true, 'saveVar', true);
        nchans = session.extracellular.nChannels;
        fs = session.extracellular.sr;
        spkgrp = session.extracellular.spikeGroups.channels;
        
        % spike sorting
        rez = runKS('basepath', filepath, 'fs', fs, 'nchans', nchans,...
            'spkgrp', spkgrp, 'saveFinal', true, 'viaGui', false,...
            'trange', [0 Inf], 'outFormat', 'ns');
        
        % fix manual curation
        fixSpkAndRes('grp', [], 'fs', fs);
        
%         spikes = loadSpikes('session', session);
%         spikes = fixCEspikes('basepath', filepath, 'saveVar', false,...
%             'force', true);
%         cm = ProcessCellMetrics('session', session,...
%             'manualAdjustMonoSyn', false, 'summaryFigures', false,...
%             'debugMode', true, 'transferFilesFromClusterpath', false,...
%             'submitToDatabase', false);
        
        %                 cell_metrics = CellExplorer('metrics', cm);
        
        % cluster validation
%         mu = [];
%         spikes = cluVal('spikes', spikes, 'basepath', filepath, 'saveVar', true,...
%             'saveFig', false, 'force', true, 'mu', mu, 'graphics', true,...
%             'vis', 'on', 'spkgrp', spkgrp);
%         
%         % firing rate
%         % firing rate
%         binsize = 60;
%         winBL = [10 * 60 30 * 60];
%         fr = firingRate(spikes.times, 'basepath', filepath,...
%             'graphics', false, 'saveFig', false,...
%             'binsize', binsize, 'saveVar', true, 'smet', 'MA',...
%             'winBL', winBL);
        
    end
end

% second analysis (depends on first run and load data)
if forceA
    for i = 1 : nsessions
        % file
        filepath = char(fullfile(basepath, dirnames(i)));
        cd(filepath)
        [datename, basename] = fileparts(filepath);
        [~, datename] = fileparts(datename);
        spikes = d{i, 3}.spikes;
        session = d{i, 1}.session;
        cm = d{i, 2}.cell_metrics;
        
        cm = CellExplorer('metrics', cm);
        %         d{i, 3}.spikes = spikes;
        
        % firing rate
        binsize = 60;
        winBL = [10 * 60 30 * 60];
        fr = firingRate(spikes.times, 'basepath', filepath,...
            'graphics', false, 'saveFig', false,...
            'binsize', binsize, 'saveVar', true, 'smet', 'MA',...
            'winBL', winBL);
        
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rearrange data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
set(groot,'defaultAxesTickLabelInterpreter','none');
set(groot,'defaulttextinterpreter','latex');
set(groot,'defaultLegendInterpreter','latex');

close all
grp = [1 : 8];          % which tetrodes to plot
state = 2;              % 1 - awake; 2 - NREM
FRdata = 'norm';        % plot absolute fr or normalized
unitClass = 'int';      % plot 'int', 'pyr', or 'all'
suFlag = true;          % plot only su or all units
p1 = false;
p2 = true;

for i = 1 : nsessions
    
    session = d{i, 1}.session;
    cm = d{i, 2}.cell_metrics;
    spikes = d{i, 3}.spikes;
    ss = d{i, 4}.SleepState;
    fr = d{i, 5}.fr;
    datInfo = d{i, 6}.datInfo;
    
    % states
    states = {ss.ints.WAKEstate, ss.ints.NREMstate, ss.ints.REMstate};
    for ii = 1 : length(states)
        tStates{ii} = InIntervals(fr.tstamps, states{ii});
        t{ii} = fr.tstamps(tStates{ii});
        frStates{ii} = mean(fr.strd(:, tStates{ii}), 2);
    end
    
    % cell class
    pyr = strcmp(cm.putativeCellType, 'Pyramidal Cell');
    int = strcmp(cm.putativeCellType, 'Narrow Interneuron');
    
    su = ones(1, length(spikes.ts));    % override
    if isfield(spikes, 'su') && suFlag
        su = spikes.su';
    end
    
    % specific grp
    grpidx = zeros(1, length(spikes.shankID));
    for ii = 1 : length(grp)
        grpidx = grpidx | spikes.shankID == grp(ii);
    end
    
    if strcmp(unitClass, 'pyr')
        units = pyr & su & grpidx;
    elseif strcmp(unitClass, 'int')
        units = int & su & grpidx;
    else
        pyr = ones(1, length(spikes.ts));     % override
    end
    
    switch FRdata
        case 'norm'
            data = fr.norm;
            ytxt = 'norm. MFR';
        case 'strd'
            data = fr.strd;
            ytxt = 'MFR [Hz]';
    end
    
    tstamps = fr.tstamps / 60;
    nsamps = cumsum(datInfo.nsamps);
    
    % firing rate vs. time. 1 fig per session
    if p1
        figure
        plot(tstamps, (data(units, :))')
        hold on
        medata = median((data(units, :)), 1);
        % plot(tstamps, medata, 'k', 'LineWidth', 5)
        stdshade(data(units, :), 0.3, 'k', tstamps)
        for ii = 1 : length(nsamps) - 1
            plot([nsamps(ii) nsamps(ii)] / fs / 60, ylim, '--k')
        end
        axis tight
        Y = ylim;
        fill([states{state} fliplr(states{state})]' / 60, [Y(1) Y(1) Y(2) Y(2)],...
            'b', 'FaceAlpha', 0.15,  'EdgeAlpha', 0);
        ylim([0 3])
        ylabel(ytxt)
        suptitle(dirnames{i})
    end
    
    % mfr in selected state across sessions (mean +- std)
    if p2
        if i == 1
            fh = figure;
        end
        ax = gca;
        bar(ax, i, mean(frStates{state}))
        hold on
    end
end
xticks(1 : nsessions)
xticklabels(sessionDate)



% for i = 1 : nsessions
%     session = d{i, 1}.session;
%     cm = d{i, 2}.cell_metrics;
%     spikes = d{i, 3}.spikes;
%     ss = d{i, 4}.SleepState;
%     fr = d{i, 5}.fr;
%     datInfo = d{i, 6}.datInfo;
% 
%  % states
%     states = {ss.ints.WAKEstate, ss.ints.NREMstate, ss.ints.REMstate};
%     for ii = 1 : length(states)
%         tStates{ii} = InIntervals(fr.tstamps, states{ii});
%         t{ii} = fr.tstamps(tStates{ii});
%         frStates{ii} = mean(fr.strd(:, tStates{ii}), 2);
%     end
%     
%     % cell class
%     pyr = strcmp(cm.putativeCellType, 'Pyramidal Cell');
%     int = strcmp(cm.putativeCellType, 'Narrow Interneuron');
%     % pyr = ones(1, length(spikes.ts));     % override
%     
%     if isfield(spikes, 'su')
%         su = spikes.su';
%     else
%         su = ones(1, length(spikes.ts));
%     end
%     %     su = ones(1, length(spikes.ts));    % override
%     
%     % specific grp
%     grpidx = zeros(1, length(spikes.shankID));
%     for ii = 1 : length(grp)
%         grpidx = grpidx | spikes.shankID == grp(ii);
%     end
%     
%     units = pyr & su & grpidx;
%     switch FRdata
%         case 'norm'
%             data = fr.norm;
%             ytxt = 'norm. MFR';
%         case 'strd'
%             data = fr.strd;
%             ytxt = 'MFR [Hz]';
%     end
% 
% end