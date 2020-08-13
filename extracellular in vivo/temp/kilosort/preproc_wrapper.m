% preproc_wrapper
basepath = 'D:\tempData\lh50\2020-04-21_12-05-16';
cd(basepath)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% open ephys
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'E:\Leore\lh56\2020-08-12_08-42-18';
rmvch = [13 16 23 24] + 1;
mapch = [25 26 27 28 30 1 2 29 3 : 14 31 0 15 16 17 : 24 32 33 34] + 1;
exp = [2];
rec = cell(max(exp), 1);
% rec{1} = [1 2];
datInfo = preprocOE('basepath', basepath, 'exp', exp, 'rec', rec,...
    'rmvch', rmvch, 'mapch', mapch, 'concat', true, 'nchans', 35);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% session info (cell explorer foramt)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
session = CE_sessionTemplate(pwd, 'viaGUI', true,...
    'force', true, 'saveVar', true);      
basepath = session.general.basePath;
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% field
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
intens = [100 150 200 250 300];
fepsp = getfEPSPfromOE('basepath', basepath, 'fname', '', 'nchans', nchans,...
    'spkgrp', spkgrp, 'intens', intens, 'concat', false, 'saveVar', true,...
    'force', true);  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% kilosort
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rez = runKS('basepath', basepath, 'fs', fs, 'nchans', nchans,...
    'spkgrp', spkgrp, 'saveFinal', true, 'viaGui', false,...
    'cleanDir', false, 'trange', [0 Inf], 'outFormat', 'ns');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fix manual curation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fixSpkAndRes('grp', [], 'fs', fs);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% cell explorer
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% spikes and cell metrics
fixSpkAndRes('grp', [], 'fs', fs);
spikes = loadSpikes('session', session);
spikes = fixCEspikes('basepath', filepath, 'saveVar', false,...
    'force', true);
cell_metrics = ProcessCellMetrics('session', session,...
    'manualAdjustMonoSyn', false, 'summaryFigures', false,...
    'debugMode', true, 'transferFilesFromClusterpath', false,...
    'submitToDatabase', false);

cell_metrics = CellExplorer('metrics', cell_metrics);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spikes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% cluster validation
mu = [];
spikes = cluVal('spikes', spikes, 'basepath', filepath, 'saveVar', true,...
    'saveFig', false, 'force', true, 'mu', mu, 'graphics', true,...
    'vis', 'on', 'spkgrp', spkgrp);

% firing rate
binsize = 60;
winBL = [5 * 60 60 * 60 * 3];
winBL = [1 Inf];
fr = firingRate(spikes.times, 'basepath', filepath, 'graphics', false, 'saveFig', false,...
    'binsize', binsize, 'saveVar', true, 'smet', 'MA', 'winBL', winBL);

% CCG
binSize = 0.001; dur = 0.12; % low res
binSize = 0.0001; dur = 0.02; % high res
[ccg, t] = CCG({xx.times{:}}, [], 'duration', dur, 'binSize', binSize);
u = 20;
plotCCG('ccg', ccg(:, u, u), 't', t, 'basepath', basepath,...
    'saveFig', false, 'c', {'k'}, 'u', spikes.UID(u));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% sleep states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
bz_LFPfromDat(basepath, 'noPrompts', true)

badch = setdiff([session.extracellular.electrodeGroups.channels{:}],...
    [session.extracellular.spikeGroups.channels{:}]);
SleepScoreMaster(basepath, 'noPrompts', true, 'rejectChannels', badch)

TheStateEditor

ce_LFPfromDat(session)
bz_LFPfromDat(filepath)


% states
states = {SleepState.ints.WAKEstate, SleepState.ints.NREMstate, SleepState.ints.REMstate};
for ii = 1 : length(states)
    tStates{ii} = InIntervals(fr.tstamps, states{ii});
    t{ii} = fr.tstamps(tStates{ii});
    frStates{ii} = mean(fr.strd(:, tStates{ii}), 2);
end


