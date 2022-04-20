% wrapper for batch processing

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mname = 'lh100';
forceL = true;
forceA = true;

pcond = ["tempflag"];
ncond = [""];

% load vars from each session
varsFile = ["fr"; "sr"; "spikes"; "st_metrics"; "swv_metrics";...
    "cell_metrics"; "sleep_states"; "ripp.mat"; "datInfo"; "session"];
varsName = ["fr"; "sr"; "spikes"; "st"; "swv"; "cm"; "ss"; "ripp";...
    "datInfo"; "session"];
if ~exist('v', 'var') || forceL
    [v, basepaths] = getSessionVars('mname', mname, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', pcond, 'ncond', ncond);
end
nsessions = length(basepaths);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% analyze data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% templateCal = ss.info.calibrationData;

for isession = 1 : nsessions

    % file
    basepath = basepaths{isession};
    cd(basepath)
    [~, basename] = fileparts(basepath);
    session = CE_sessionTemplate(pwd, 'viaGUI', false,...
        'forceDef', true, 'forceL', true, 'saveVar', true);
    basepath = session.general.basePath;
    nchans = session.extracellular.nChannels;
    fs = session.extracellular.sr;
    spkgrp = session.extracellular.spikeGroups.channels;
    [~, basename] = fileparts(basepath);


    % params
    %         session = v(isession).session;
    %         nchans = session.extracellular.nChannels;
    %         fs = session.extracellular.sr;
    %         spkgrp = session.extracellular.spikeGroups.channels;

    % add timebins to datInfo
    %         nbins = 4;
    %         reqPnt = 6 * 60 * 60;
    %         [timebins, timepnt] = metaInfo_timebins('reqPnt', reqPnt,...
    %             'nbins', nbins);
    %         winCalc = mat2cell(timebins, ones(nbins, 1), 2);
    %
    %         % spk lfp
    %         frange = [0.5, 4; 5, 12; 50, 80];
    %         sl = spklfp_wrapper('basepath', basepath, 'winCalc', winCalc,...
    %             'ch', 9, 'frange', frange,...
    %             'graphics', true, 'saveVar', false);
    %
    %         % spike timing metrics
    %         st = spktimesMetrics('winCalc', winCalc, 'forceA', true);

    %         tbins_txt = {'0-3ZT', '3-6ZT', '6-9ZT', '9-12ZT',...
    %             '12-15ZT', '15-18ZT', '18-21ZT', '21-24ZT'};
    %         psdBins = psd_states_timebins('basepath', pwd,...
    %             'chEeg', [], 'forceA', true, 'graphics', true,...
    %             'timebins', chunks, 'saveVar', true,...
    %             'sstates', [1, 4, 5], 'tbins_txt', tbins_txt);

    %         psdBins = psd_timebins('basepath', pwd,...
    %             'chEeg', [34], 'forceA', true, 'graphics', true,...
    %             'timebins', chunks, 'saveVar', true);

    %         fr = firingRate(v(isession).spikes.times, 'basepath', basepath, 'graphics', true,...
    %             'binsize', 60, 'saveVar', true, 'smet', 'GK', 'winBL',...
    %             [0 timepoints], 'winCalc', [0, Inf], 'forceA', true);

    %         frBins(isession) = fr_timebins('basepath', pwd,...
    %             'forceA', false, 'graphics', true,...
    %             'timebins', chunks, 'saveVar', true);
    

% create emg signal from accelerometer data
acc = EMGfromACC('basepath', basepath, 'fname', [basename, '.lfp'],...
    'nchans', nchans, 'ch', nchans - 2 : nchans, 'saveVar', true, 'fsIn', 1250,...
    'graphics', false, 'force', false);

% call for acceleration
sSig = as_prepSig([basename, '.lfp'], acc.mag,...
    'eegCh', [5 : 7], 'emgCh', [], 'saveVar', true, 'emgNchans', [],...
    'eegNchans', nchans, 'inspectSig', false, 'forceLoad', false,...
    'eegFs', 1250, 'emgFs', 1250, 'eegCf', [], 'emgCf', [10 450], 'fs', 1250);

    % calc spec
    fh = figure;
    spec = calc_spec('sig', [], 'fs', 1250, 'graphics', true,...
        'saveVar', true, 'padfft', -1, 'winstep', 1,...
        'logfreq', false, 'ftarget', [], 'ch', [{5 : 7}, {16}]);

end


cell_metrics = CellExplorer('basepaths', basepaths);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% general params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'force', true, 'saveVar', true);
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;

sessionIdx = 1 : nsessions;
stateidx = [1, 4, 5];
grp = [1 : 4];                  % which tetrodes to plot
unitClass = 'pyr';              % plot 'int', 'pyr', or 'all'
suFlag = 1;                     % plot only su or all units
frBoundries = [0 Inf];          % include only units with fr greater than

[nsub] = numSubplots(length(sessionIdx));
[cfg_colors, cfg_names, ~] = as_loadConfig([]);
setMatlabGraphics(false)

% arrange title names
for isession = 1 : nsessions
    sessionName{isession} = dirnames{isession}(length(mname) + 2 : end);
    basepath = char(fullfile(mousepath, dirnames{isession}));
    basepaths{isession} = fullfile(mousepath, dirnames{isession});
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

