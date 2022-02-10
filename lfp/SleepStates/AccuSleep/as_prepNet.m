
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data base
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% basepaths from xls file
xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\ss_database.xlsx';
xlsfile = dir(xlsname);
ssDB = readtable(fullfile(xlsfile.folder, xlsfile.name));

% create basepaths and check that files exist
dbIdx = find(contains(ssDB.Path, 'Testing'));
basepaths = fullfile(ssDB.Path, ssDB.Filename);
idx1 = contains(ssDB.EMG_ACC, 'emg');
idx2 = ssDB.tempflag; idx2(isnan(idx2)) = 0;
basepaths = basepaths(logical(idx2));
rmidx = cellfun(@isempty, basepaths);
basepaths = basepaths(~rmidx);

% check that files exist
for ipath = 1 : length(basepaths)
    basepath = basepaths{ipath};
    [~, basename] = fileparts(basepath);
    sigfile = fullfile(basepath, [basename, '.sleep_sig.mat']);
    labelsmanfile = fullfile(basepath, [basename, '.sleep_labelsMan.mat']);
    if ~exist(sigfile, 'file') || ~exist(labelsmanfile, 'file')
        error('missing %s', basename)
    end   
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% config file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load configuration file
configfile = 'D:\Code\slutsky_ECInVivo\lfp\SleepStates\AccuSleep\as_config.mat';
cfg = as_loadConfig();

% weights
gldstrd = labels;
idx = gldstrd ~= 8;
weights = histcounts(gldstrd(idx)) / length(gldstrd(idx));
weights = round(weights * 100) / 100;       % round to two decimals
weights(4) = weights(4) + 1 - sum(weights); % add remainder to NREM
cfg.weights = weights;
cfg.weights = [cfg.weights];

% colors
cfg.colors{1} = [240 110 110] / 255;
cfg.colors{2} = [240 170 125] / 255;
cfg.colors{3} = [150 205 130] / 255;
cfg.colors{4} = [110 180 200] / 255;
cfg.colors{5} = [170 100 170] / 255;
cfg.colors{6} = [200 200 100] / 255;
cfg.colors{7} = [200 200 200] / 255;
cfg.colors = cfg.colors(:);

% state names
cfg.names = {'WAKE'; 'QWAKE'; 'LSLEEP'; 'NREM'; 'REM'; 'N/REM'; 'BIN'};

% general
cfg.fs = 1250;
cfg.epochLen = 1;
cfg.minBoutLen = 0;
cfg.nstates = length(cfg.names) - 1; 

% save
save(configfile, 'cfg')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% train
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfg = as_loadConfig();
cntxEpochs = 63;
tic
[net, netInfo] = AccuSleep_train(basepaths, cntxEpochs);
netInfo.trainingTime = toc / 60;

% labels duration
for ipath = 1 : length(basepaths)
    basepath = basepaths{ipath};
    [~, basename] = fileparts(basepath);
    labelsmanfile = fullfile(basepath, [basename, '.sleep_labelsMan.mat']);
    load(labelsmanfile, 'labels')
    netInfo.labelsDuration(ipath) = sum(labels < cfg.nstates + 1);
end
 
netInfo.cfg = cfg;
netInfo.cntxEpochs = cntxEpochs;
netpath = 'D:\Code\slutsky_ECInVivo\lfp\SleepStates\AccuSleep\trainedNetworks';
netname = ['net_',  datestr(datetime, 'yymmdd_HHMMss')]; 
save(fullfile(netpath, netname), 'net', 'netInfo')      

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% test net (on remaining part of the data)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
% create calibration (based on entire dataset, doesn't matter)
calibrationData = createCalibrationData(standardizeSR(EEG_orig, fs, 128),...
    standardizeSR(EMG_orig, fs, 128), gldstrd, 128, epochLen);

% classify
[labels_net, netScores] = AccuSleep_classify(standardizeSR(EEG2, fs, 128),...
    standardizeSR(EMG2, fs, 128), net, 128, epochLen, calibrationData, minBoutLen);
    
% manually inspect model output and gldstrd
AccuSleep_viewer(EEG2, EMG2, fs, epochLen, labels_net, [])
AccuSleep_viewer(EEG2, EMG2, fs, epochLen, labels2, [])

% check precision
[netPrecision, netRecall] = as_cm(labels2, labels_net);

