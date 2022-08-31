   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lh111
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% user input
mname           = 'lh111';
basepath        = 'H:\lh111\2022-08-22_09-48-47';
exp             = [1 : 2];

% dat from oe 
mapch = 1 : 20;
rmvch = [5, 6];
rec = cell(max(exp), 1);
datInfo = preprocOE('basepath', basepath, 'exp', exp, 'rec', rec,...
    'rmvch', rmvch, 'mapch', mapch,...
    'nchans', length(mapch), 'fsIn', 20000);

% go to new folder
[mousepath, baseTime] = fileparts(basepath);
cd(mousepath)
dn = datenum(baseTime, 'yyyy-MM-dd');
recData = datestr(dn, 'yyMMdd');
fnames = dir(mousepath);
fidx = contains({fnames.name}, recData);
cd(fnames(fidx).name)

% session params
session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'forceDef', true, 'forceL', true, 'saveVar', true);      
basepath = session.general.basePath;
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;
[~, basename] = fileparts(basepath);

% clip bad parts
clear datfile
datfile = {fullfile(basepath, [basename, '.dat'])};

clip = cell(1, length(datfile));
clip{1} = [seconds(minutes(368)), seconds(minutes(438))] * fs;
datInfo = preprocDat('orig_files', datfile, 'mapch', 1 : nchans,...
    'rmvch', [], 'nchans', nchans, 'saveVar', true,...
    'chunksize', 1e7, 'precision', 'int16', 'clip', clip);

% spike detection from temp_wh
[spktimes, ~] = spktimesWh('basepath', basepath, 'fs', fs, 'nchans', nchans,...
    'spkgrp', spkgrp, 'saveVar', true, 'saveWh', true,...
    'graphics', false, 'force', true, 'winWh', [0 Inf]);

% spike rate per tetrode
for igrp = 1 : length(spkgrp)
    spktimes{igrp} = spktimes{igrp} / fs;
end
sr = firingRate(spktimes, 'basepath', basepath,...
    'graphics', true, 'binsize', 60, 'saveVar', 'sr', 'smet', 'none',...
    'winBL', [0 Inf]);

% create ns files 
dur = [];
t = [];
spktimes2ns('basepath', basepath, 'fs', fs,...
    'nchans', nchans, 'spkgrp', spkgrp, 'mkClu', true,...
    'dur', dur, 't', t, 'grps', [1 : length(spkgrp)],...
    'spkFile', 'temp_wh');

% create lfp file
LFPfromDat('basepath', basepath, 'cf', 450, 'chunksize', 5e6,...
    'nchans', nchans, 'fsOut', 1250, 'fsIn', fs)    

% create emg signal from accelerometer data
acc = EMGfromACC('basepath', basepath, 'fname', [basename, '.lfp'],...
    'nchans', nchans, 'ch', nchans - 2 : nchans, 'saveVar', true, 'fsIn', 1250,...
    'graphics', false, 'force', true);

% sleep sig
sSig = as_prepSig([basename, '.lfp'], acc.mag,...
    'eegCh', [7 : 10], 'emgCh', [], 'saveVar', true, 'emgNchans', [],...
    'eegNchans', nchans, 'inspectSig', false, 'forceLoad', true,...
    'eegFs', 1250, 'emgFs', 1250, 'eegCf', [], 'emgCf', [10 450], 'fs', 1250);
labelsmanfile = [basename, '.sleep_labelsMan.mat'];
AccuSleep_viewer(sSig, [], labelsmanfile)

% calc spec
spec = calc_spec('sig', [], 'fs', 1250, 'graphics', true,...
    'saveVar', true, 'padfft', -1, 'winstep', 5,...
    'ftarget', [], 'ch', {[7 : 10]},...
    'force', true, 'logfreq', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lh110
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% user input
mname           = 'lh110';
basepath        = 'F:\Data\lh110\lh110_220816_090700';
blocks          = [1 : 3];

% tank to dat 
mapch           = [];
rmvch           = [2, 4];
store           = 'Raw2';
chunksize       = 300;
clip            = cell(1, 1);
datInfo = tdt2dat('basepath', basepath, 'store', store, 'blocks',  blocks,...
    'chunksize', chunksize, 'mapch', mapch, 'rmvch', rmvch, 'clip', clip);

% fepsp 
intens          = [300, 500, 700];
protocol_id     = 'pair';
ch              = 1;
blocks          = 2;                            
fepsp_tdtPipeline('basepath', basepath, 'blocks', blocks,...
    'protocol_id', protocol_id, 'recsuffix', '', 'intens', intens,...
    'ch', ch, 'mapch', mapch', 'rmvch', rmvch, 'store', store)

% move files to session folder
[~, basename] = fileparts(basepath);
recpath = fullfile(basepath, basename);
mkdir(recpath)
fnames = dir(['*' basename '*']);
for ifile = 1 : length(fnames)
    if ~fnames(ifile).isdir
        filename = fnames(ifile).name;
        newfile = fullfile(recpath, filename);
        movefile(fnames(ifile).name, newfile, 'f')
    end
end
movefile('graphics', recpath, 'f')

% move xml file
mousepath = fileparts(basepath);
xmlfile = dir(fullfile(mousepath, [mname, '.xml']));
newname = strrep(xmlfile.name, mname, basename);
newfile = fullfile(recpath, newname);
copyfile(fullfile(mousepath, xmlfile.name), newfile)

% move to session folder
cd(recpath)
session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'forceDef', true, 'forceL', true, 'saveVar', true);      
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;
basepath = session.general.basePath;
[~, basename] = fileparts(basepath);

% sleep signals
sSig = as_prepSig([basename, '.lfp'], [],...
    'eegCh', [1], 'emgCh', [2], 'saveVar', true, 'emgNchans', nchans,...
    'eegNchans', nchans, 'inspectSig', false, 'forceLoad', true,...
    'eegFs', 1250, 'emgFs', 1250, 'eegCf', [], 'emgCf', [50 450], 'fs', 1250);
labelsmanfile = [basename, '.sleep_labelsMan.mat'];
AccuSleep_viewer(sSig, [], labelsmanfile)

% classify with a network
calData = [];
load(fullfile(mousepath, ['lh110_220803_092100.sleep_states.mat']), 'ss')
calData = ss.info.calibrationData;
ss = as_classify(sSig, 'basepath', pwd, 'inspectLabels', false,...
    'saveVar', true, 'forceA', true, 'netfile', [],...
    'graphics', true, 'calData', calData);

% calc spec
spec = calc_spec('sig', [], 'fs', 1250, 'graphics', true, 'saveVar', true,...
    'padfft', -1, 'winstep', 5, 'logfreq', true, 'ftarget', [],...
    'ch', [{1}], 'force', true);

% -------------------------------------------------------------------------
% fepsp in relation to states

% load data
varsFile = ["fepsp_traces"; "fepsp_results"; "sleep_states"];
varsName = ["traces"; "results"; "ss"];
v = getSessionVars('basepaths', {basepath}, 'varsFile', varsFile,...
    'varsName', varsName);

% get stim indices in specific state. note some stims may be attributed to
% two or more states due to overlap in stateEpochs. This can prevented by
% using labels instead.
nstates = 6;
clear stateStim
for istate = 1 : nstates
    stateStim(:, istate) = InIntervals(v.results.info.stimIdx, v.ss.stateEpochs{istate});
end
sum(stateStim)
% histcounts(ss.labels(round(v.results.info.stimIdx)), [1 : 7])

nstims = length(v.results.info.stimIdx);
nintens = length(intens);
idxCell = num2cell(reshape(1 : nstims, nstims / nintens, nintens), 1);
clear amp traces
for istate = 1 : nstates
    for iintens = 1 : nintens
        stimIdx = stateStim(idxCell{iintens}, istate);
        nstimState(istate, iintens) = sum(stimIdx);
        amp{istate, iintens} = v.results.all_traces.Amp{iintens}(:, stimIdx);
        traces{istate}(iintens, :) = mean(v.traces{iintens}(:, stimIdx), 2);
    end
end

% organize in struct
protocol_info = fepsp_getProtocol("protocol_id", 'pair', "fs", fs);
fstates.tstamps = protocol_info.Tstamps;
fstates.nstims = nstimState;
fstates.amp = amp;
fstates.traces = traces;
% cell2nanmat(amp, 2)

% check stim time
fh = figure;
plot(sSig.emg_rms)
xidx = v.results.info.stimIdx;
hold on
plot([xidx; xidx], ylim, '--k', 'LineWidth', 3)


% -------------------------------------------------------------------------
% fepsp from sessions

% load vars from each session
varsFile = ["datInfo"; "session"; "fepsp_traces"; "fepsp_results";...
    "sleep_states"];
varsName = ["datInfo"; "session"; "traces"; "results"; "ss"];
[v, basepaths] = getSessionVars('mname', 'lh110', 'varsFile', varsFile,...
    'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
    'xlsname', '');
nfiles = length(basepaths);

for ifile = 1 : nfiles
    [~, basenames{ifile}] = fileparts(basepaths{ifile});
end
basenames = string(basenames);


clear ydata
for ifile = 1 : nfiles    
    tmp = cell2nanmat(cellfun(@(x) mean(x, 2, 'omitnan'), v(ifile).traces, 'uni', false), 2);
    for iintens = 1 : 3
        ydata{iintens}(ifile, :) = tmp(:, iintens);
    end
end
protocol_info = fepsp_getProtocol("protocol_id", 'pair', "fs", fs);
xdata = protocol_info.Tstamps;

% fepsp per state
ifile = 3;
nstates = 6;
intens = [350, 500, 650];
clear stateStim
for istate = 1 : nstates
    stateStim(:, istate) = InIntervals(v(ifile).results.info.stimIdx, v(ifile).ss.stateEpochs{istate});
end
sum(stateStim)
% histcounts(v(ifile).ss.labels(round(v(ifile).results.info.stimIdx)), [1 : 7])

nstims = length(v(ifile).results.info.stimIdx);
nintens = length(intens);
idxCell = num2cell(reshape(1 : nstims, nstims / nintens, nintens), 1);
% idxCell{1} = [1 : 20];
% idxCell{2} = [21 : 40];
% idxCell{3} = [41 : 59];
clear amp traces
for istate = 1 : nstates
    for iintens = 1 : nintens
        stimIdx = stateStim(idxCell{iintens}, istate);
        nstimState(istate, iintens) = sum(stimIdx);
        amp{istate, iintens} = v(ifile).results.all_traces.Amp{iintens}(:, stimIdx);
        traces{istate}(iintens, :) = mean(v(ifile).traces{iintens}(:, stimIdx), 2);
    end
end

% organize in struct
protocol_info = fepsp_getProtocol("protocol_id", 'pair', "fs", fs);
fstates.tstamps = protocol_info.Tstamps;
fstates.nstims = nstimState;
fstates.amp = amp;
fstates.traces = traces;
% cell2nanmat(amp, 2)





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lh109
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% user input
mname           = 'lh109';
basepath        = 'F:\Data\lh110\lh110_220816_090700';
blocks          = [1 : 3];
cd(basepath)

% tank to dat 
mapch           = [];
rmvch           = [2 : 2 : 6];
store           = 'Raw1';
chunksize       = 300;
clip            = cell(1, 1);
datInfo = tdt2dat('basepath', basepath, 'store', store, 'blocks',  blocks,...
    'chunksize', chunksize, 'mapch', mapch, 'rmvch', rmvch, 'clip', clip);

% move files to session folder
[~, basename] = fileparts(basepath);
recname = strrep(basename, 'lh110', mname);
recpath = fullfile(basepath, recname);
mkdir(recpath)
fnames = dir(['*' basename '*']);
for ifile = 1 : length(fnames)
    if ~fnames(ifile).isdir
        filename = strrep(fnames(ifile).name, basename, recname);
        newfile = fullfile(recpath, filename);
        movefile(fnames(ifile).name, newfile, 'f')
    end
end

% move xml file
mousepath = fileparts(basepath);
xmlfile = dir(fullfile(mousepath, [mname, '.xml']));
newname = strrep(xmlfile.name, mname, recname);
newfile = fullfile(recpath, newname);
copyfile(fullfile(mousepath, xmlfile.name), newfile)

% move to session folder
cd(recpath)
session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'forceDef', true, 'forceL', true, 'saveVar', true);      
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;
basepath = session.general.basePath;
[~, basename] = fileparts(basepath);

% sleep signals
sSig = as_prepSig([basename, '.lfp'], [],...
    'eegCh', [1], 'emgCh', [2], 'saveVar', true, 'emgNchans', nchans,...
    'eegNchans', nchans, 'inspectSig', false, 'forceLoad', true,...
    'eegFs', 1250, 'emgFs', 1250, 'eegCf', [], 'emgCf', [50 450], 'fs', 1250);
labelsmanfile = [basename, '.sleep_labelsMan.mat'];
AccuSleep_viewer(sSig, [], labelsmanfile)

%%% artifacts when cable moves. states could be better. 

% classify with a network
calData = ss.info.calibrationData;
ss = as_classify(sSig, 'basepath', pwd, 'inspectLabels', false,...
    'saveVar', true, 'forceA', true, 'netfile', [],...
    'graphics', true, 'calData', calData);

% calc spec
spec = calc_spec('sig', [], 'fs', 1250, 'graphics', true, 'saveVar', true,...
    'padfft', -1, 'winstep', 5, 'logfreq', true, 'ftarget', [],...
    'ch', [{1}, {3}], 'force', true);

% plot
plot_spec(spec, 'ch', 2, 'logfreq', true, 'saveFig', false,...
    'axh', [])


