basepaths = [
    {'K:\Data\lh95\lh95_210824_083300'},...
    {'K:\Data\lh95\lh95_210825_080400'},...
    {'I:\lh96\lh96_211126_072000'},...
    {'F:\Data\Processed\lh96\lh96_211201_070100'},...
    {'F:\Data\Processed\lh96\lh96_211202_070500'},...
    {'F:\Data\Processed\lh96\lh96_211207_071500'},...
    {'K:\Data\lh99\lh99_211218_090630'},...    
    {'K:\Data\lh99\lh99_211219_085802'},...
    {'K:\Data\lh99\lh99_211220_091903'},...
    ];

nsessions = length(basepaths);

for isession = 1 : nsessions
    basepath = basepaths{isession};
    cd(basepath)
    
    [timebins, timepnt] = metaInfo_timebins('basepath', basepath,...
        'reqPnt', 5.5 * 60 * 60);
%     
%     % spike timing metrics
%     st = spktimesMetrics('basepath', basepath, 'winCalc', [0 timepnt],...
%         'forceA', true);
%     
%     % spike waveform metrics
%     swv = spkwvMetrics('basepath', basepath, 'forceA', true);
    
% plot state duration in timebins
session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'forceDef', false, 'forceL', false, 'saveVar', false);     
[totDur, epLen] = as_plotZT('nwin', 8, 'sstates', [1, 2, 3, 4, 5],...
    'ss', ss, 'timebins', session.general.timebins);
totDur / 60

% select specific units
units = selectUnits('basepath', basepath, 'grp', [1 : 4],...
    'forceA', true, 'saveVar', true);

% plot fr vs. time
plot_FRtime_session('basepath', pwd, 'grp', [1 : 4],...
    'muFlag', false, 'saveFig', false,...
    'dataType', 'strd', 'muFlag', false)

% number of units per spike group
frBoundries = [];
plot_nunits_session('basepath', basepath, 'frBoundries', frBoundries)

frBins = fr_timebins('basepath', basepath, 'forceA', true);

end

cell_metrics = CellExplorer('basepaths', basepaths);
