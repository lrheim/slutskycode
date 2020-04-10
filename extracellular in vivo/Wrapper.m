% this is a wrapper for processing extracellular data.
% contains calls to various functions.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 1: file conversion
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = '/media/leore/Samsung_T5/Data/Dat/lh49/lh49_200325/';
store = 'Raw1';
fs = 24414.06;
blocks = [5, 10];
chunksize = 300;
% mapch = [1 : 16];
% mapch = [];
mapch = [1 : 2 : 7, 2 : 2 : 8, 9 : 2 : 15, 10 : 2 : 16];
rmvch = [];
clip = cell(1, 1);

% tank to dat
[info] = tdt2dat('basepath', basepath, 'store', store, 'blocks',  blocks,...
    'chunksize', chunksize, 'mapch', mapch, 'rmvch', rmvch, 'clip', clip);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 1b: open ephys
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'E:\Data\Dat\lh50\2020-04-02_17-11-26';
preprocOE('basepath', basepath, 'exp', [2])

% snip stim


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 2: LFP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load lfp
ch = [1 : 16];
chavg = {1 : 4; 5 : 7; 8 : 11; 12 : 15};
chavg = {};
lfp = getLFP('basepath', basepath, 'ch', ch, 'chavg', chavg,...
    'fs', 1250, 'interval', [0 inf], 'extension', 'lfp',...
    'savevar', true, 'forceL', true, 'basename', '');

% load with stim (tdt). DONT FORGET TO CHANGE NAME
lfp = getfEPSPfromTDT('basepath', basepath, 'andname', 'stability2',...
    'blocks', blocks, 'mapch', mapch, 'ch', ch, 'clip', clip,...
    'saveVar', true, 'fdur', 0.1, 'concat', true);

% inter ictal spikes
thr = [5 0];
marg = 0.05;
binsize = (2 ^ nextpow2(30 * lfp.fs));
ch = 1;
smf = 7;
iis = getIIS('sig', double(lfp.data(:, ch)), 'fs', lfp.fs, 'basepath', basepath,...
    'graphics', true, 'saveVar', true, 'binsize', binsize,...
    'marg', marg, 'basename', '', 'thr', thr, 'smf', 7,...
    'saveFig', false, 'forceA', true, 'spkw', false, 'vis', true);

% burst suppression
vars = {'std', 'max', 'sum'};
bs = getBS('sig', double(lfp.data(:, ch)), 'fs', lfp.fs,...
    'basepath', basepath, 'graphics', true,...
    'saveVar', true, 'binsize', 1, 'BSRbinsize', binsize, 'smf', smf,...
    'clustmet', 'gmm', 'vars', vars, 'basename', '',...
    'saveFig', false, 'forceA', true, 'vis', true);

% anesthesia states
[bs, iis, ep] = aneStates_m('ch', 1, 'basepath', basepath,...
    'basename', '', 'graphics', true, 'saveVar', true,...
    'saveFig', false, 'forceA', false, 'binsize', 30, 'smf', 7);
    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 3: load EMG
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% option 1:
blocks = [2];
rmvch = [2:4];
emg = getEMG(basepath, 'Stim', blocks, rmvch);

% option 2:
emglfp = getEMGfromLFP(double(lfp.data(:, chans)), 'emgFs', 10, 'saveVar', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 4: spikes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load
spikes = getSpikes('basepath', basepath, 'saveMat', true,...
    'noPrompts', true, 'forceL', false);

% review clusters
mu = find(spikes.isi > 1);
mu = sort([mu', 2, 4, 19, 22, 26, 42, 44, 46, 48, 50, 52, 55, 59, 64, 67, 69, 75]);
spikes = cluVal(spikes, 'basepath', basepath, 'saveVar', true,...
    'saveFig', true, 'force', true, 'mu', mu, 'graphics', true,...
    'vis', 'off');

% compare number of spikes and clusters from clustering to curation 
numSpikes = getNumSpikes(basepath, spikes);

% separation of SU and MU
plotIsolation(basepath, spikes, false)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 4: CCH temporal dynamics 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% use buzcode CCG
% low res
binSize = 0.001; % [s]
dur = 0.05;
[ccg t] = CCG({spikes.times{:}}, [], 'duration', dur, 'binSize', binSize);
% high res
binSize = 0.0001; 
dur = 0.02;
[ccg t] = CCG({spikes.times{:}}, [], 'duration', dur, 'binSize', binSize);

for i = 1 : nunits
    nspikes(i) = length(spikes.times{i});
end

u = spikes.UID(nspikes > 6300);
u(1) = [];

u = sort([20 27]);
plotCCG('ccg', ccg(:, u, u), 't', t, 'basepath', basepath,...
    'saveFig', false, 'c', {'k'}, 'u', spikes.UID(u));

uu = datasample(u, 7, 'replace', false);
plotCCG('ccg', ccg(:, uu, uu), 't', t, 'basepath', basepath,...
    'saveFig', false, 'c', {'k'}, 'u', spikes.UID(uu));

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 5: cell classification based on waveform
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CellClass = cellClass(cat(1, spikes.rawWaveform{:})', 'fs', spikes.samplingRate, 'man', true); 

%%%%%%%%%%%%%%%/home/leore/code/buzcode/externalPackages/chronux_2_12/spectral_analysis/pointtimes/binspikes.m%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 6: calculate mean firing rate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
winBL = [info.lns(1) info.lns(3)] * spikes.samplingRate * 60;
fr = FR(spikes.times(spikes.su), 'basepath', basepath, 'graphics', false, 'saveFig', false,...
    'binsize', 60, 'saveVar', true, 'smet', 'MA');

filename = bz_BasenameFromBasepath(basepath);
filename = [filename '.Raw1.Info.mat'];
load(filename);
info.labels = {''};
lns = cumsum(info.blockduration / 60);
lns = [1e-6 lns];
info.lns = lns(1);
save(filename, 'info');

f = figure;
subplot(2, 1, 1)
plotFRtime('fr', fr, 'units', true, 'spktime', spikes.times,...
    'avg', false, 'lns', info.lns, 'lbs', info.labels,...
    'raster', false, 'saveFig', false);
title('')
xlabel('')
subplot(2, 1, 2)
plotFRtime('fr', fr, 'units', false, 'spktime', spikes.times,...
    'avg', true, 'lns', info.lns, 'lbs', info.labels,...
    'raster', false, 'saveFig', false);
xlabel('Time [m]')
title('')
figname = 'Firing Rate';
export_fig(figname, '-tif', '-transparent')
        
[nunits, nbins] = size(fr.strd);
tFR = ([1 : nbins] / (60 / fr.binsize) / 60);
p = plot(tFR, log10(fr.strd));
hold on
plot(tFR, mean(log10(fr.strd)), 'k', 'LineWidth', 3)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 7: concatenate spikes from different sessions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parentdir = 'E:\Data\Others\Buzsaki';
basepath = parentdir;
structname = 'spikes';
spikes = catStruct(parentdir, structname);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 8: get video projection from ToxTrack file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
filename = 'TestProject';
vid = getVid(filename, 'basepath', basepath, 'graphics', true, 'saveFig', false, 'saveVar', false);


