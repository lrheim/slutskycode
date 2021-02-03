% preproc_wrapper
basepath = 'D:\VMs\shared\lh58\lh58_200901_080917';
cd(basepath)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% open ephys
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'F:\fepsp\lh79\2021-02-03_16-26-15';
rmvch = [1 : 35, 37 : 43];
rmvch = [1 : 19, 21 : 27];
% mapch = [26 27 28 29 31 2 3 30 4 5 6 7 8 9 10 11 12 13 14 15 32 1 16 17 18 19 20 21 22 23 24 25 33 34 35];
mapch = [1 : 43];
mapch = [1 : 27];
exp = [2];
rec = cell(max(exp), 1);
% rec{1} = [8 : 15];
datInfo = preprocOE('basepath', basepath, 'exp', exp, 'rec', rec,...
    'rmvch', rmvch, 'mapch', mapch, 'concat', true,...
    'nchans', length(mapch), 'fsIn', 30000);

%%%%%%%%%%%%%%%%%%%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% tdt
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'D:\VMs\shared\lh47\lh47_200308';
store = 'Raw1';
blocks = [3 : 10];
chunksize = 300;
mapch = [1 : 16];
% mapch = [1 : 2 : 7, 2 : 2 : 8, 9 : 2 : 15, 10 : 2 : 16];
rmvch = [1, 3, 5, 7, 9 : 16];
clip = cell(1, 1);
% clip{39} = [480 * 60 Inf];
datInfo = tdt2dat('basepath', basepath, 'store', store, 'blocks',  blocks,...
    'chunksize', chunksize, 'mapch', mapch, 'rmvch', rmvch, 'clip', clip);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% session info (cell explorer foramt)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'force', true, 'saveVar', true);      
basepath = session.general.basePath;
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% field
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
intens = [20 15 17.5];
fepsp = fEPSPfromDat('basepath', basepath, 'fname', '', 'nchans', nchans,...
    'spkgrp', spkgrp, 'intens', intens, 'saveVar', true,...
    'force', true, 'extension', 'dat', 'recSystem', 'oe',...
    'protocol', 'stp', 'anaflag', true, 'inspect', false, 'fsIn', fs,...
    'cf', 0);  

intens = [300];
fepsp = fEPSPfromWCP('basepath', basepath, 'sfiles', [],...
    'sufx', 'stp', 'force', true, 'protocol', 'stp',...
    'intens', intens, 'inspect', false, 'fs', 30000);

fepsp = fEPSP_analysis('fepsp', fepsp, 'basepath', basepath,...
    'force', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spike sorting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ks
rez = runKS('basepath', basepath, 'fs', fs, 'nchans', nchans,...
    'spkgrp', spkgrp, 'saveFinal', true, 'viaGui', false,...
    'trange', [0 Inf], 'outFormat', 'ns');

% kk
[spktimes, ~] = spktimesWh('basepath', basepath, 'fs', fs, 'nchans', nchans,...
    'spkgrp', spkgrp, 'saveVar', true, 'saveWh', false,...
    'graphics', false);
        
% create ns files for sorting
spktimes2ks('basepath', basepath, 'fs', fs,...
    'nchans', nchans, 'spkgrp', spkgrp, 'mkClu', true,...
    'dur', 240, 't', [], 'psamp', [], 'grps', [1 : length(spkgrp)]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fix manual curation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fixSpkAndRes('grp', 2, 'fs', fs);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% cell explorer
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% spikes and cell metrics
fixSpkAndRes('grp', [], 'fs', fs);
spikes = loadSpikes('session', session);
spikes = fixCEspikes('basepath', basepath, 'saveVar', false,...
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
spikes = cluVal('spikes', spikes, 'basepath', basepath, 'saveVar', true,...
    'saveFig', false, 'force', true, 'mu', mu, 'graphics', false,...
    'vis', 'on', 'spkgrp', spkgrp);

% firing rate
binsize = 60;
winBL = [5 * 60 20 * 60];
% winBL = [1 Inf];
fr = firingRate(spikes.times, 'basepath', basepath, 'graphics', false, 'saveFig', false,...
    'binsize', binsize, 'saveVar', true, 'smet', 'MA', 'winBL', winBL);

figure
subplot(2, 1, 1)
data = fr.norm;
plot(fr.tstamps / 60, data')
hold on
plot(fr.tstamps / 60, mean(data, 1), 'k', 'LineWidth', 3)
ylabel('Norm. FR')
subplot(2, 1, 2)
data = fr.strd;
plot(fr.tstamps / 60, data')
hold on
plot(fr.tstamps / 60, mean(data, 1), 'k', 'LineWidth', 3)
ylabel('FR [Hz]')
xlabel('Time [m]')

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
% create lfp
LFPfromDat('basepath', basepath, 'cf', 450, 'chunksize', 5e6,...
    'nchans', nchans, 'fsOut', 1250,...
    'fsIn', fs)   

% load lfp
lfp = getLFP('basepath', basepath, 'ch', [spkgrp{:}], 'chavg', {},...
    'fs', 1250, 'interval', [0 inf], 'extension', 'lfp',...
    'savevar', true, 'forceL', true, 'basename', '');

badch = setdiff([session.extracellular.electrodeGroups.channels{:}],...
    [session.extracellular.spikeGroups.channels{:}]);
SleepScoreMaster(basepath, 'noPrompts', true, 'rejectChannels', badch)

TheStateEditor

% states
states = {SleepState.ints.WAKEstate, SleepState.ints.NREMstate, SleepState.ints.REMstate};
for ii = 1 : length(states)
    tStates{ii} = InIntervals(fr.tstamps, states{ii});
    t{ii} = fr.tstamps(tStates{ii});
    frStates{ii} = mean(fr.strd(:, tStates{ii}), 2);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spike detection routine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% create wh.dat
ops = opsKS('basepath', basepath, 'fs', fs, 'nchans', nchans,...
    'spkgrp', spkgrp, 'trange', [0 Inf]);
preprocessDataSub(ops);

% detect spikes
[spktimes, spkch] = spktimesWh('basepath', basepath, 'fs', fs, 'nchans', nchans,...
    'spkgrp', spkgrp, 'saveVar', true, 'chunksize', 2048 ^ 2 + 64,...
    'graphics', false);

% create ns files for kk sorting
% spktimes2ks

% firing rate per tetrode. note that using times2rate requires special care
% becasue spktimes is given in samples and not seconds
binsize = 60 * fs;
winCalc = [0 Inf];
[sr.strd, sr.edges, sr.tstamps] = times2rate(spktimes, 'binsize', binsize,...
    'winCalc', winCalc, 'c2r', false);
% convert counts to rate
sr.strd = sr.strd ./ (diff(sr.edges) / fs);
% fix tstamps
sr.tstamps = sr.tstamps / binsize;

figure, plot(sr.tstamps, sr.strd)
legend