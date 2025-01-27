
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data base
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load configuration file
cfg = as_loadConfig();

% basepaths from xls file
xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\ss_database.xlsx';
xlsfile = dir(xlsname);
ssDB = readtable(fullfile(xlsfile.folder, xlsfile.name));

% create basepaths 
basepaths = fullfile(ssDB.Path, ssDB.Filename);

% select based on acc / emg
% idx1 = contains(ssDB.EMG_ACC, 'acc');
% basepaths = basepaths(logical(idx1));

% select based on tempFlag
idx2 = ssDB.tempflag; idx2(isnan(idx2)) = 0;
basepaths = basepaths(logical(idx2));

% assert folders exist
rmidx = cellfun(@isempty, basepaths);
basepaths = basepaths(~rmidx);
if sum(rmidx) > 1
    warning('some folders missing')
end

% check files
for ipath = 1 : length(basepaths)
    
    % files
    basepath = basepaths{ipath};
    [~, basename] = fileparts(basepath);
    cd(basepath)
    sigfile = fullfile(basepath, [basename, '.sleep_sig.mat']);
    labelsmanfile = fullfile(basepath, [basename, '.sleep_labelsMan_4st.mat']);

    % check exists
    if ~exist(sigfile, 'file') || ~exist(labelsmanfile, 'file')
        error('%s missing', basename)
    end
    
    % load info and such
    load([basename, '.sleep_sig.mat'], 'info');
    load([basename, '.sleep_sig.mat'], 'spec_freq');
    load(labelsmanfile)
    sf(ipath) = length(spec_freq);  

    % check sampling rate
    if info.eegFs ~= cfg.fs
        error('%s mismatch in sampling rate', basename)
    end

    % check at least one label for each state
    if ~all([1 : cfg.nstates] == unique(labels(labels <= cfg.nstates))')
        error('%s does not contain all states', basename)
    end

end

% check that spec frequency is the same for all files. indicated that the
% same version of calc_spec and prep_sig was used.
if length(unique(sf)) > 1 
    error('some spectrograms differ, check manually')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% combine states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% change one state to another. make sure the order is correct.
stSwitch = [6, 5;...    % N/REM to original REM
    4, 3;...            % NREM to LSLEEP (will be NREM)
    5, 4;...            % REM to new position
    8, 5;...            % none to new position
    7, 5];              % none to new position

for ipath = 1 : length(basepaths)

    % files
    basepath = basepaths{ipath};
    [~, basename] = fileparts(basepath);
    cd(basepath)
    labelsmanfile = fullfile(basepath, [basename, '.sleep_labelsMan.mat']);
    labelsnewfile = fullfile(basepath, [basename, '.sleep_labelsMan_4st.mat']);
    load(labelsmanfile)

    for i_sw = 1 : size(stSwitch, 1)
        labels(labels == stSwitch(i_sw, 1)) = stSwitch(i_sw, 2);
    end
    
    save(labelsnewfile, 'labels')

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% train
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cntxBouts = 51;

tic
[net, netInfo] = AccuSleep_train(basepaths, cntxBouts);
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
netInfo.cntxBouts = cntxBouts;
netInfo.files = basepaths;
netpath = 'D:\Code\slutsky_ECInVivo\lfp\SleepStates\AccuSleep\trainedNetworks';
netname = ['net_',  datestr(datetime, 'yymmdd_HHMMss')]; 
save(fullfile(netpath, netname), 'net', 'netInfo')      


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% config file - 4 states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% weights (must load any labelsMan file)
gldstrd = labels;
idx = gldstrd ~= 5;
weights = histcounts(gldstrd(idx)) / length(gldstrd(idx));
weights = round(weights * 100) / 100;       % round to two decimals
weights(3) = weights(3) + 1 - sum(weights); % add remainder to NREM
cfg.weights = weights;

% colors
cfg.colors{1} = [240 110 110] / 255;
cfg.colors{2} = [240 170 125] / 255;
cfg.colors{3} = [110 180 200] / 255;
cfg.colors{4} = [170 100 170] / 255;
cfg.colors{5} = [200 200 200] / 255;
cfg.colors = cfg.colors(:);

% state names
cfg.names = {'WAKE'; 'QWAKE'; 'NREM'; 'REM'; 'BIN'};

% general
cfg.fs = 1250;
cfg.boutLen = 1;
cfg.minBoutLen = 0;
cfg.nstates = length(cfg.names) - 1; 

% save
configfile = 'D:\Code\slutsky_ECInVivo\lfp\SleepStates\AccuSleep\as_config.mat';
save(configfile, 'cfg')


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% config file - 6 states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% weights (must load any labelsMan file)
gldstrd = labels;
idx = gldstrd < 7;
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
cfg.boutLen = 1;
cfg.minBoutLen = 0;
cfg.nstates = length(cfg.names) - 1; 

% save
configfile = 'D:\Code\slutsky_ECInVivo\lfp\SleepStates\AccuSleep\as_config.mat';
save(configfile, 'cfg')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% config file - emg
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear cfg

% weights
cfg.weights = [0.45, 0.55];

% colors
cfg.colors{1} = [150, 70, 55] / 255;
cfg.colors{2} = [200, 170, 100] / 255;
cfg.colors{3} = [200 200 200] / 255;
cfg.colors = cfg.colors(:);

% state names
cfg.names = {'High-EMG'; 'Low-EMG'; 'BIN'};

% general
cfg.fs = 1250;
cfg.boutLen = 1;
cfg.minBoutLen = 0;
cfg.nstates = length(cfg.names) - 1; 

% save
configfile = 'D:\Code\slutsky_ECInVivo\lfp\SleepStates\AccuSleep\as_configEmg.mat';
save(configfile, 'cfg')

