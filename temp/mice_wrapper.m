   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lh123
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% user input
mname           = 'lh123';
basepath        = 'K:\Data\lh123\2022-12-29_09-01-02';
exp             = [1 : 3];

% dat from oe 
mapch = 1 : 19;
rmvch = [10];
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
clear orig_files
orig_files{1} = 'K:\Data\lh123\lh123_221229_090102\lh123_221229_090102.dat';
% orig_files{2} = 'K:\Data\lh122\lh122_221230_181824\lh122_221230_181824.dat';
clip = cell(1, length(orig_files));
clip{1} = [seconds(minutes(60 * 24)), Inf] * 20000;
datInfo = preprocDat('orig_files', orig_files, 'mapch', 1 : nchans,...
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
spktimes2ns('basepath', basepath, 'fs', fs,...
    'nchans', nchans, 'spkgrp', spkgrp, 'mkClu', true,...
    'dur', [], 't', [], 'grps', [1 : length(spkgrp)],...
    'spkFile', 'temp_wh');

delete('temp_wh.dat')

% create lfp file
LFPfromDat('basepath', basepath, 'cf', 450, 'chunksize', 5e6,...
    'nchans', nchans, 'fsOut', 1250, 'fsIn', fs)    

% create emg signal from accelerometer data
acc = EMGfromACC('basepath', basepath, 'fname', [basename, '.lfp'],...
    'nchans', nchans, 'ch', nchans - 2 : nchans, 'saveVar', true, 'fsIn', 1250,...
    'graphics', false, 'force', true);

% sleep sig
sSig = as_prepSig([basename, '.lfp'], acc.mag,...
    'eegCh', [12 : 15], 'emgCh', [], 'saveVar', true, 'emgNchans', [],...
    'eegNchans', nchans, 'inspectSig', false, 'forceLoad', true,...
    'eegFs', 1250, 'emgFs', 1250, 'eegCf', [], 'emgCf', [10 450], 'fs', 1250);
labelsmanfile = [basename, '.sleep_labelsMan.mat'];
AccuSleep_viewer(sSig, [], labelsmanfile)

% calc spec
spec = calc_spec('sig', [], 'fs', 1250, 'graphics', true,...
    'saveVar', true, 'padfft', -1, 'winstep', 5,...
    'ftarget', [], 'ch', {[12 : 15]},...
    'force', true, 'logfreq', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lh127
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% user input
mname           = 'lh127';
basepath        = 'J:\Data\lh123\2023-01-01_09-01-44';
exp             = [1 : 4];

% dat from oe 
mapch = 1 : 19;
rmvch = [9];
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
clear orig_files
orig_files{1} = 'J:\Data\lh123\lh123_230101_090144\lh123_230101_090144.dat';
orig_files{2} = 'J:\Data\lh127\lh127_230101_205752\lh127_230101_205752.dat';
clip = cell(1, length(orig_files));
% clip{1} = [seconds(minutes(1304)), Inf] * 20000;
datInfo = preprocDat('orig_files', orig_files, 'mapch', 1 : nchans,...
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
spktimes2ns('basepath', basepath, 'fs', fs,...
    'nchans', nchans, 'spkgrp', spkgrp, 'mkClu', true,...
    'dur', [], 't', [], 'grps', [1 : length(spkgrp)],...
    'spkFile', 'temp_wh');

delete('temp_wh.dat')

% create lfp file
LFPfromDat('basepath', basepath, 'cf', 450, 'chunksize', 5e6,...
    'nchans', nchans, 'fsOut', 1250, 'fsIn', fs)    

% create emg signal from accelerometer data
acc = EMGfromACC('basepath', basepath, 'fname', [basename, '.lfp'],...
    'nchans', nchans, 'ch', nchans - 2 : nchans, 'saveVar', true, 'fsIn', 1250,...
    'graphics', false, 'force', true);

% sleep sig
sSig = as_prepSig([basename, '.lfp'], acc.mag,...
    'eegCh', [12 : 15], 'emgCh', [], 'saveVar', true, 'emgNchans', [],...
    'eegNchans', nchans, 'inspectSig', false, 'forceLoad', true,...
    'eegFs', 1250, 'emgFs', 1250, 'eegCf', [], 'emgCf', [10 450], 'fs', 1250);
labelsmanfile = [basename, '.sleep_labelsMan.mat'];
AccuSleep_viewer(sSig, [], labelsmanfile)

% calc spec
spec = calc_spec('sig', [], 'fs', 1250, 'graphics', true,...
    'saveVar', true, 'padfft', -1, 'winstep', 5,...
    'ftarget', [], 'ch', {[12 : 15]},...
    'force', true, 'logfreq', true);

  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lh122
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% user input
mname           = 'lh122';
basepath        = 'K:\Data\lh122\2022-12-31_09-01-12';
exp             = [1];

% dat from oe 
mapch = 1 : 19;
rmvch = [];
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
clear orig_files
orig_files{1} = 'K:\Data\lh122\lh122_221229_090102\lh122_221229_090102.dat';
clip = cell(1, length(orig_files));
clip{1} = [0, seconds(minutes(1440))] * 20000;
% clip{2} = [seconds(minutes(1440)), seconds(minutes(573))] * 20000;
datInfo = preprocDat('orig_files', orig_files, 'mapch', 1 : nchans,...
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
spktimes2ns('basepath', basepath, 'fs', fs,...
    'nchans', nchans, 'spkgrp', spkgrp, 'mkClu', true,...
    'dur', [], 't', [], 'grps', [1 : length(spkgrp)],...
    'spkFile', 'temp_wh');

delete('temp_wh.dat')

% create lfp file
LFPfromDat('basepath', basepath, 'cf', 450, 'chunksize', 5e6,...
    'nchans', nchans, 'fsOut', 1250, 'fsIn', fs)    

% create emg signal from accelerometer data
acc = EMGfromACC('basepath', basepath, 'fname', [basename, '.lfp'],...
    'nchans', nchans, 'ch', nchans - 2 : nchans, 'saveVar', true, 'fsIn', 1250,...
    'graphics', false, 'force', true);

% sleep sig
sSig = as_prepSig([basename, '.lfp'], acc.mag,...
    'eegCh', [1 : 4], 'emgCh', [], 'saveVar', true, 'emgNchans', [],...
    'eegNchans', nchans, 'inspectSig', false, 'forceLoad', true,...
    'eegFs', 1250, 'emgFs', 1250, 'eegCf', [], 'emgCf', [10 450], 'fs', 1250);
labelsmanfile = [basename, '.sleep_labelsMan.mat'];
AccuSleep_viewer(sSig, [], labelsmanfile)

% calc spec
spec = calc_spec('sig', [], 'fs', 1250, 'graphics', true,...
    'saveVar', true, 'padfft', -1, 'winstep', 5,...
    'ftarget', [], 'ch', {[1 : 4]},...
    'force', true, 'logfreq', true);

