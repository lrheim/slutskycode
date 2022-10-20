
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
idx1 = contains(ssDB.EMG_ACC, 'acc');
idx2 = ssDB.tempflag; idx2(isnan(idx2)) = 0;
basepaths = basepaths(logical(idx2));
% basepaths = basepaths(logical(idx1));
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

% % edit spectrogram
% for ipath = 1 : length(basepaths)
%     basepath = basepaths{ipath};
%     [~, basename] = fileparts(basepath);
%     sigfile = fullfile(basepath, [basename, '.sleep_sig.mat']);
%     sSig = load(sigfile);
% 
%     spec = calc_spec('sig', sSig.eeg,...
%         'fs', 1250, 'graphics', false, 'saveVar', false, 'force', true,...
%         'padfft', -1, 'winstep', 1, 'logfreq', false,...
%         'ftarget', [0.5 : 0.2 : 20, 20.5 : 0.5 : 50]);
%     sSig.spec = spec.s;
%     sSig.spec_tstamps = spec.tstamps;
%     sSig.spec_freq = spec.freq;
% 
%     save(sigfile, '-struct', 'sSig')
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% config file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load configuration file
configfile = 'D:\Code\slutsky_ECInVivo\lfp\SleepStates\AccuSleep\as_config.mat';
cfg = as_loadConfig();

% weights (must load any labelsMan file)
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
cntxEpochs = 41;

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
netInfo.files = basepaths;
netpath = 'D:\Code\slutsky_ECInVivo\lfp\SleepStates\AccuSleep\trainedNetworks';
netname = ['net_',  datestr(datetime, 'yymmdd_HHMMss')]; 
save(fullfile(netpath, netname), 'net', 'netInfo')      

