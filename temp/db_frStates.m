% fr_states

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data base
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% aCSF
basepaths = [
    {'E:\Data\Processed\lh95\lh95_210824_083300'},...
    {'F:\Data\Processed\lh96\lh96_211201_070100'},...
    {'K:\Data\lh99\lh99_211218_090630'},...
    ];
%     {'F:\Data\Processed\lh96\lh96_211124_073800'},...
%     {'D:\Data\lh93\lh93_210811_102035'},...

% local ket
basepaths = [
    {'E:\Data\Processed\lh95\lh95_210825_080400'},...
    {'F:\Data\Processed\lh96\lh96_211126_072000'},...
    {'F:\Data\Processed\lh96\lh96_211202_070500'},...
    {'K:\Data\lh99\lh99_211219_085802'},...
    ];

% baclofen
basepaths = [
    {'F:\Data\Processed\lh96\lh96_211207_071500'},...
    {'K:\Data\lh99\lh99_211220_091903'},...
    ];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% reanalyze something
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load vars from each session
forceL = false;
if ~exist('v', 'var') || forceL
    varsFile = ["fr"; "spikes"; "datInfo"; "session"];
    varsName = ["fr"; "spikes"; "datInfo"; "session"];
    v = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
        'varsName', varsName);
end
nsessions = length(basepaths);

% recalculate firing rate
for isession = 1 : nsessions
    basepath = basepaths{isession};
    cd(basepath)
    [mousename, basename] = fileparts(basepath);
    [~, mousename] = fileparts(mousename);
%     timepnt = v(isession).session.general.timepnt;
%     winBL = [0 timepnt];
%     fr = firingRate(v(isession).spikes.times, 'basepath', basepath,...
%         'graphics', true, 'binsize', 60, 'saveVar', true,...
%         'smet', 'none', 'winBL', winBL, 'winCalc', [0, Inf]);
%    
%     if isfield(v(isession).spikes, 'units')
%         grp = v(isession).spikes.units.grp;
%     else
%         grp = [];
%     end   
%     units = selectUnits('basepath', basepath, 'grp', grp, 'saveVar', true,...
%         'forceA', true, 'frBoundries', [0 Inf; 0 Inf],...
%         'spikes', v(isession).spikes);
%     
%     [timebins, timepnt] = metaInfo_timebins('reqPnt', 5.5 * 60 * 60,...
%         'nbins', 8);
    timebins = v(isession).session.general.timebins;
    fr_timebins('basepath', pwd,...
        'forceA', true, 'graphics', true,...
        'timebins', timebins, 'saveVar', true, 'sstates', [1, 4, 5]);
end

% params
cfg = as_loadConfig();
nstates = cfg.nstates;
unitChar = {'RS', 'FS'};
unitClr = {'b', 'r'};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% concate sessions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load concatenated data from basepaths
frCat = catFrSessions('basepaths', basepaths, 'binidx', 3);

% assing vars
structvars(frCat);
stateMfr = frCat.stateMfr;         
stateRat = frCat.stateRat;         
units = frCat.units;               
unitsGini = frCat.unitsGini;       
unitsMfr = frCat.unitsMfr;         
mfr = frCat.mfr;                   
giniCoeff = frCat.giniCoeff;       
stableIdx = frCat.stableIdx;       
sessionIdx = frCat.sessionIdx;     
tstamps = frCat.tstamps;          

% manualy remove units by criteria
unitsClean(1, :) = units(1, :) & unitsGini' & unitsMfr';
unitsClean(2, :) = units(2, :) & unitsGini' & unitsMfr';

unitNo = 2;
prismIdx = num2str(sessionIdx);
prismIdx = string(prismIdx(unitsClean(unitNo, :)));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics - box plot of mfr state ratio divided to sextiles
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

plot_FRstates_sextiles('stateMfr', stateMfr([1, 4], :), 'units', unitsClean,...
    'ntiles', 6, 'saveFig', false)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics - box plot of mfr across states divided by median
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
setMatlabGraphics(false)

fh = figure;
for iunit = 1 : 2
    
    % firing rate median
    medFr = median(mfr(units(iunit, :)));
    yLimit = ceil([0 prctile(stateMfr(:, units(iunit, :)), 98 ,'all')]);
    
    % high firing units
    subplot(2, 2, iunit + iunit - 1)
    medUnits = units(iunit, :) & (mfr > medFr)';
    dataMat = stateMfr(:, medUnits);
    plot_boxMean('dataMat', dataMat', 'clr', 'k')
    bh = findobj(gca, 'Tag', 'Box');
    bh = flipud(bh);
    for ibox = 1 : length(bh)
        patch(get(bh(ibox), 'XData'), get(bh(ibox), 'YData'),...
            cfg.colors{stateIdx(ibox)}, 'FaceAlpha', 0.5)
    end
    ylabel('Firing Rate [Hz]')
    xticklabels(cfg.names)
    subtitle(sprintf('High MFR %s = %d', unitChar{iunit}, sum(medUnits)))
    ylim(yLimit)
    
    % low firing units
    subplot(2, 2, iunit + 1 + iunit - 1)
    medUnits = units(iunit, :) & (mfr < medFr)';
    dataMat = stateMfr(:, medUnits);
    plot_boxMean('dataMat', dataMat', 'clr', 'k')
    bh = findobj(gca, 'Tag', 'Box');
    bh = flipud(bh);
    for ibox = 1 : length(bh)
        patch(get(bh(ibox), 'XData'), get(bh(ibox), 'YData'),...
            cfg.colors{stateIdx(ibox)}, 'FaceAlpha', 0.5)
    end
    ylabel('Firing Rate [Hz]')
    xticklabels(cfg.names)
    subtitle(sprintf('Low MFR %s = %d', unitChar{iunit}, sum(medUnits)))
    ylim(yLimit)
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics - gini ceoff vs. mfr at basline colored by stability
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
setMatlabGraphics(false)

fh = figure;
for iunit = 1 : 2
    subplot(2, 2, iunit)
    unitIdx = unitsOrig(iunit, :) & stableIdx';
    scatter(mfr(unitIdx), giniCoeff(unitIdx), 300, '.b')
    hold on
    unitIdx = unitsOrig(iunit, :) & ~stableIdx';
    scatter(mfr(unitIdx), giniCoeff(unitIdx), 300, '.r')
    set(gca, 'XScale', 'log')
    ylim([0 1])
    plot(xlim, [0.5, 0.5], '--k')
    subtitle(unitChar{iunit})
    xlabel('Firing Rate [Hz')
    ylabel('Gini Coefficient')
    
    subplot(2, 2, iunit + 2)
    unitIdx = unitsOrig(iunit, :) & stableIdx';
    scatter(stateRat(unitIdx), giniCoeff(unitIdx), 300, '.b')
    hold on
    unitIdx = unitsOrig(iunit, :) & ~stableIdx';
    scatter(stateRat(unitIdx), giniCoeff(unitIdx), 300, '.r')
    ylim([0 1])
    plot(xlim, [0.5, 0.5], '--k')
    xlabel({sprintf('%s - %s /', cfg.names{4}, cfg.names{1}),...
        sprintf('%s + %s', cfg.names{4}, cfg.names{1})})
    ylabel('Gini Coefficient')
end

fh = figure;
unitsGini = find((unitsOrig(1, :) | unitsOrig(2, :)) & giniIdx');
for igini = 1 : length(unitsGini)
    subplot(ceil(length(unitsGini) / 2), 2, igini)
    plot([1 : length(frMat)] / 60, frMat(unitsGini(igini), :))
    subtitle(sprintf('Unit #%d, Gini = %.2f',...
        unitsGini(igini), giniCoeff(unitsGini(igini))))
end

fh = figure;
unitsGini = find((unitsOrig(1, :) | unitsOrig(2, :)) & ~giniIdx');
unitsGini = unitsGini(randperm(length(unitsGini), 16));
for igini = 1 : length(unitsGini)
    subplot(ceil(length(unitsGini) / 2), 2, igini)
    plot([1 : length(frMat)] / 60, frMat(unitsGini(igini), :))
    subtitle(sprintf('Unit #%d, Gini = %.2f',...
        unitsGini(igini), giniCoeff(unitsGini(igini))))
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% to prism
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

frCat = catFrSessions('basepaths', basepaths, 'binidx', []);
structvars(frCat);
stateMfr = frCat.stateMfr;         
stateRat = frCat.stateRat;         
units = frCat.units;               
unitsGini = frCat.unitsGini;       
unitsMfr = frCat.unitsMfr;         
mfr = frCat.mfr;                   
giniCoeff = frCat.giniCoeff;       
stableIdx = frCat.stableIdx;       
sessionIdx = frCat.sessionIdx;     
tstamps = frCat.tstamps;     

% firing rate vs. time across all units, aligned to point of injection
[frMat, timeIdx] = alignFR2pnt('basepaths', basepaths, 'dataType', 'norm');

% prepare for prism
unitIdx = num2str(sessionIdx);
unitIdx(~unitsMfr) = repmat('m', sum(~unitsMfr), 1);
unitIdx(~unitsGini) = repmat('g', sum(~unitsGini), 1);

unitNo = 1;
prismData = frMat(units(unitNo, :), :)';
prismIdx = string(unitIdx(units(unitNo, :)))';
prismTstamps = [1 : length(frMat)] / 60;
max(timeIdx) / 60


% single session
dataType = 'norm';
data = fr.(dataType)(units.idx(unitNo, :), :)';
data(~isfinite(data)) = nan;
excludeIdx = ~units.gini' | ~units.mfrBL';
prismIdx = excludeIdx(units.idx(unitNo, :));
tstamps = fr.tstamps / 60 / 60;