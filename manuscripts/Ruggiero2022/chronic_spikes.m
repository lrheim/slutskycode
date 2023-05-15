

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% analysis per mouse
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mname = 'lh126';

varsFile = ["fr"; "datInfo"; "session"; "units"];
varsName = ["fr"; "datInfo"; "session"; "units"];
xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
[v, basepaths] = getSessionVars('mname', mname, 'varsFile', varsFile,...
    'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
    'xlsname', xlsname);
nfiles = length(basepaths);


% fr in time bins bins
for ifile = 1 : nfiles

    % file
    basepath = basepaths{ifile};
    cd(basepath)
    [~, basename] = fileparts(basepath);

    % print progress
    fprintf('sessions_wrapper: working on session %d of %d, %s\n',...
        ifile, nfiles, basename)

    % add timebins to datInfo
    [timebins, timepnt] = metaInfo_timebins('reqPnt', [], 'nbins', 4);
    timebins / 60 / 60

    % mfr by states in time bins
    frBins = fr_timebins('basepath', pwd, 'forceA', true, 'graphics', true,...
        'timebins', timebins, 'saveVar', true, 'sstates', [1, 4, 5]);

end


% other stuff
for ifile = 1 : nfiles

    % file
    basepath = basepaths{ifile};
    cd(basepath)
    [~, basename] = fileparts(basepath);

    % print progress
    fprintf('sessions_wrapper: working on session %d of %d, %s\n',...
        ifile, nfiles, basename)

    % select specific units
    load([basename, '.spikes.cellinfo.mat'])
    units = selectUnits('basepath', pwd, 'grp', [1 : 4], 'saveVar', true,...
        'forceA', true, 'frBoundries', [0.0 Inf; 0.0 Inf],...
        'spikes', spikes, 'altClean', 2);

    fr = calc_fr(spikes.times, 'basepath', basepath,...
        'graphics', true, 'binsize', 60, 'saveVar', true, 'forceA', true,...
        'smet', 'none', 'winBL', [0 Inf], 'winCalc', [0, Inf]);

end

cell_metrics = CellExplorer('basepaths', basepaths);


% concatenate var from different sessions
[expData, xData] = sessions_catVarTime('mname', mname,...
    'dataPreset', {'sr', 'fr', 'spec'}, 'graphics', true, 'dataAlt', 1,...
    'basepaths', {}, 'xTicksBinsize', 6, 'markRecTrans', true);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get MFR in time bins per unit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% sessionList: all five sessions should be considered

mname = {'lh122'; 'lh123'; 'lh126'; 'lh129'; 'lh130'};
sstates = [1, 4];

mfrcat = cell(2, 2);
frMed = [-1];      % take units with mfr > med (pos), < med (neg), or all []
for imouse = 1 : length(mname)

    % reload data
    varsFile = ["fr"; "fr_bins"; "datInfo"; "session"; "units"];
    varsName = ["fr"; "frBins"; "datInfo"; "session"; "units"];
    xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
    [v, basepaths] = getSessionVars('mname', mname{imouse}, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
        'xlsname', xlsname);
    nfiles = length(basepaths);

    % organize in cell array
    cnt = 1;
    clear mfr stateRat stateGain
    for ifile = 1 : nfiles
        for ibin = 1 : 4
            for iunit = 1 : 2

                unitIdx = v(ifile).units.clean(iunit, :);
                unitMfr = v(ifile).frBins(ibin).mfr(unitIdx)';
                allMfr = v(ifile).frBins(ibin).mfr';
                if isempty(frMed)
                    unitMfrIdx = ones(1, length(allMfr));
                elseif frMed > 0
                    unitMfrIdx = allMfr > median(unitMfr);
                elseif frMed < 0
                    unitMfrIdx = allMfr < median(unitMfr)';
                end
                unitIdx = unitIdx & unitMfrIdx;

                for istate = 1 : length(sstates)
                                       
                    mfr{cnt, istate, iunit} = v(ifile).frBins(ibin).states.mfr(unitIdx, sstates(istate));

                end
                stateRat{cnt, iunit} = squeeze(v(ifile).frBins(ibin).states.ratio(1, 4, unitIdx));
                stateGain{cnt, iunit} = squeeze(v(ifile).frBins(ibin).states.gain(4, unitIdx));
            end
            cnt = cnt + 1;
        end
    end

    % reorganize for prism
    for istate = 1 : 2
        for iunit = 1 : 2
            data = cell2nanmat(squeeze(mfr(:, istate, iunit)), 2);
            mfrcat{istate, iunit} = [mfrcat{istate, iunit};...
                data];
        end
    end
    iunit = 1;
    cell2nanmat(squeeze(stateRat(:, iunit)), 2);
    cell2nanmat(squeeze(stateGain(:, iunit)), 2);


end

mfrcat{2, 2}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MFR in states across mice per unit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% CHECK SESSION_LIST.XLSX

sstates = [1 : 6];
mname = {'lh122'; 'lh123'; 'lh126'; 'lh129'; 'lh130'};
clear mfr
for imouse = 1 : length(mname)
    varsFile = ["fr"; "datInfo"; "session"; "units"];
    varsName = ["fr"; "datInfo"; "session"; "units"];
    xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
    [v, basepaths] = getSessionVars('mname', mname{imouse}, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
        'xlsname', xlsname);
    nfiles = length(basepaths);

    fr = catfields([v(:).fr], 'catdef', 'cell');

    for ifile = 1 : nfiles
        for iunit = 1 : 2
            unitIdx = v(ifile).units.clean(iunit, :);
            for istate = 1 : length(sstates)
                mfr(imouse, ifile, iunit, istate) = mean(fr.states.mfr{ifile}(unitIdx, sstates(istate)));
            end
        end
    end
end

squeeze(mfr(:, :, 2, 1))

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MFR in states across mice per mouse
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% CHECK SESSION_LIST.XLSX

sstates = [1, 4];
mname = {'lh123'; 'lh126'; 'lh129'; 'lh130'};
fileIdx = [2, 2, 4, 4];
binIdx = [1, 4, 1, 4];
clear mfr
for imouse = 1 : length(mname)
    varsFile = ["fr"; "fr_bins"; "datInfo"; "session"; "units"];
    varsName = ["fr"; "frBins"; "datInfo"; "session"; "units"];
    xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
    [v, basepaths] = getSessionVars('mname', mname{imouse}, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
        'xlsname', xlsname);
    nfiles = length(basepaths);


    for ibin = 1 : length(binIdx)
        mfrTemp = v(fileIdx(ibin)).frBins(binIdx(ibin)).states.mfr;
        for iunit = 1 : 2
            unitIdx = v(fileIdx(ibin)).units.clean(iunit, :);
            for istate = 1 : length(sstates)
                mfr(imouse, ibin, iunit, istate) = mean(mfrTemp(unitIdx, sstates(istate)), 'omitnan');
            end
        end
    end
end
m4 = mfr;

mname = {'lh122'};
fileIdx = [1, 2, 2, 3];
binIdx = [4, 1, 4, 1];
clear mfr
for imouse = 1 : length(mname)
    varsFile = ["fr"; "fr_bins"; "datInfo"; "session"; "units"];
    varsName = ["fr"; "frBins"; "datInfo"; "session"; "units"];
    xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
    [v, basepaths] = getSessionVars('mname', mname{imouse}, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
        'xlsname', xlsname);
    nfiles = length(basepaths);


    for ibin = 1 : length(binIdx)
        mfrTemp = v(fileIdx(ibin)).frBins(binIdx(ibin)).states.mfr;
        for iunit = 1 : 2
            unitIdx = v(fileIdx(ibin)).units.clean(iunit, :);
            for istate = 1 : length(sstates)
                mfr(imouse, ibin, iunit, istate) = mean(mfrTemp(unitIdx, sstates(istate)), 'omitnan');
            end
        end
    end
end

iunit = 1;
istate = 1;
[squeeze(m4(:, :, iunit, istate)); squeeze(mfr(:, :, iunit, istate))]


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get MFR per unit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mname = {'lh122'; 'lh123'; 'lh126'; 'lh129'; 'lh130'};

mfr = cell(length(sstates), 2, 3);
for imouse = 1 : length(mname)

    % reload data
    varsFile = ["fr"; "datInfo"; "session"; "units"];
    varsName = ["fr"; "datInfo"; "session"; "units"];
    xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
    [v, basepaths] = getSessionVars('mname', mname{imouse}, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
        'xlsname', xlsname);
    nfiles = length(basepaths);

    % organize in cell array
    for ifile = 1 : nfiles
        for iunit = 1 : 2
            for istate = 1 : length(sstates)
                unitIdx = v(ifile).units.clean(iunit, :);
                tmpMfr = v(ifile).fr.states.mfr(unitIdx, sstates(istate));
                mfr{istate, iunit, ifile} = [mfr{istate, iunit, ifile}; tmpMfr]
            end
        end
    end
end

% state ratio according to mfr percetiles
iunit = 2;
ifile = 1;
for ifile = 1 : 3
    plot_FRstates_sextiles('stateMfr', [mfr{:, iunit, ifile}]', 'units', [],...
        'ntiles', 4, 'saveFig', false)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get MFR vs. time across mice (baclofen)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mname = {'lh96'; 'lh107'; 'lh122'};

fr = cell(length(mname), 2);
for imouse = 1 : length(mname)
    
    for iunit = 1 : 2
    
        % concatenate var from different sessions
        [expData, xData] = sessions_catVarTime('mname', mname{imouse},...
            'dataPreset', 'fr', 'graphics', false, 'dataAlt', iunit,...
            'basepaths', {}, 'xTicksBinsize', 6, 'markRecTrans', true);

        % remove nan from columns (units)
        expData(:, all(isnan(expData), 1)) = [];

        % put in cell
        fr{imouse, iunit} = expData;

    end
end

% smooth each cell and than calc mean and std and smooth across population

iunit = 2;
npt = 91;
prismMat = cell2nanmat(fr(:, iunit));
prismMat = movmean(prismMat, npt, 1, 'omitnan');
nunits = sum(~isnan(prismMat'))';
xData = [1 / 60 : 1 / 60 : length(nunits) / 60] - 30;

mfr = movmean(mean(prismMat, 2, 'omitnan'), npt);
sfr = movmean(std(prismMat, [], 2, 'omitnan') ./ sqrt(nunits), npt);
sfr(sfr == Inf) = nan;

fh = figure
plot(xData, mfr)



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% acsf
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

basepaths = [...
    "F:\Data\lh122\lh122_230109_095412";...
    "F:\Data\lh123\lh123_221228_102653";...
    "F:\Data\lh126\lh126_230117_102353";...
    "F:\Data\lh129\lh129_230214_093124";...
    "F:\Data\lh130\lh130_230405_094750"];

% reload data
varsFile = ["fr"; "fr_bins"; "datInfo"; "session"; "units"];
varsName = ["fr"; "frBins"; "datInfo"; "session"; "units"];
xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
[v, ~] = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
    'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
    'xlsname', xlsname);
nfiles = length(basepaths);


% fr vs. time
iunit = 2;
[frMat, timeIdx] = alignFR2pnt('basepaths', basepaths, 'suFlag', true,...
    'dataType', 'strd', 'iunit', iunit, 'timeIdx', [0 0 0 0 0]);

% to prism
npnts = 13;
prismMat = [smooth(mean(frMat, 2), npnts),...
    smooth(std(frMat, [], 2) / sqrt(length(frMat)), npnts)];
nunits = sum(~isnan(frMat)');

% replace last hour with first hour
xval = [-6 : 1 / 60 : 18];
shiftVal = 90;  % [min]
[~, injIdx] = min(abs(xval - 0));
injIdx = find(injIdx);
prismMat(injIdx + shiftVal : end, :) = prismMat(injIdx : end - shiftVal, :)

% fr timebins per state
sstates = [1, 4];
mfr = cell(4, length(sstates), 2);
cnt = 1;
for ifile = 1 : nfiles
    for ibin = 1 : 4
        for iunit = 1 : 2
            unitIdx = v(ifile).units.clean(iunit, :);
            for istate = 1 : length(sstates)
                data = v(ifile).frBins(ibin).states.mfr(unitIdx, sstates(istate));
                mfr{ibin, iunit, istate} = [mfr{ibin, iunit, istate}; data];
            end
        end
    end
    cnt = cnt + 1;
end

iunit = 2;
istate = 2;
cell2nanmat(squeeze(mfr(:, iunit, istate)), 2)


% per mouse: MFR across units per state per unit
clear mfr
for ifile = 1 : nfiles
    for iunit = 1 : 2
        unitIdx = v(ifile).units.clean(iunit, :);
        for istate = 1 : 2
            mfr(1, ifile, iunit, istate) =...
                mean(v(ifile).frBins(1).states.mfr(unitIdx, sstates(istate)), 'omitnan')
             mfr(2, ifile, iunit, istate) =...
                mean(v(ifile).frBins(3).states.mfr(unitIdx, sstates(istate)), 'omitnan')
        end
    end
end

iunit = 2;
istate = 1;
squeeze(mfr(:, :, iunit, istate))'

% acsf two sessions
clear basepaths
basepaths = ["F:\Data\lh107\lh107_220517_094900"; "F:\Data\lh107\lh107_220518_091200";...
    "F:\Data\lh123\lh123_221228_102653"; "F:\Data\lh123\lh123_221229_090102";...
    "F:\Data\lh126\lh126_230115_090453"; "F:\Data\lh126\lh126_230117_102353";...
    "F:\Data\lh129\lh129_230214_093124"; "F:\Data\lh129\lh129_230215_092653"];

nmice = length(basepaths);

% fr vs. time
iunit = 1;
[frMat, timeIdx] = alignFR2pnt('basepaths', {basepaths{1 : 2 : end}}, 'suFlag', true,...
    'dataType', 'strd', 'iunit', iunit, 'timeIdx', [0 0 0 0 ]);
[frMat2, timeIdx] = alignFR2pnt('basepaths', {basepaths{2 : 2 : end}}, 'suFlag', true,...
    'dataType', 'strd', 'iunit', iunit, 'timeIdx', [0 0 0 0 ]);

npt = 91;
prismMfr = movmean([mean(frMat, 2, 'omitnan'); mean(frMat2, 2, 'omitnan')], npt);
prismSfr = movmean([std(frMat, [], 2, 'omitnan') / sqrt(size(frMat, 2));...
    std(frMat2, [], 2, 'omitnan') / sqrt(size(frMat, 2))], npt);
nunits = [ones(1, length(frMat)) * size(frMat, 2), ones(1, length(frMat2)) * size(frMat2, 2)];
xData = [1 : (length(frMat) + length(frMat2))] / 60 - 24
 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% cell classification
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mname = {'lh122'; 'lh123'; 'lh126'; 'lh129'; 'lh130'};
ifile = 1;

tp = []; brst = []; un = [];
for imouse = 1 : length(mname)

    % reload data
    varsFile = ["session"; "cell_metrics"; "units"];
    varsName = ["session"; "cm"; "units"];
    xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
    [v, basepaths] = getSessionVars('mname', mname{imouse}, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
        'xlsname', xlsname);
    nfiles = length(basepaths);
    
    for ifile = 1
        basepath = basepaths{ifile};
        cd(basepath)
        tp = [tp, v(ifile).cm.troughToPeak];
        brst = [brst, v(ifile).cm.st_royer];
        un = [un, v(ifile).units.clean];
    end

end

fh = figure;
iunit = 1;
prismMat = [tp(logical(un(iunit, :)))', brst(logical(un(iunit, :)))'];
scatter(prismMat(:, 1), prismMat(:, 2), 'k', 'filled')
hold on
iunit = 2;
prismMat = [tp(logical(un(iunit, :)))', brst(logical(un(iunit, :)))'];
scatter(prismMat(:, 1), prismMat(:, 2), 'r', 'filled')
set(gca, 'yscale', 'log')

