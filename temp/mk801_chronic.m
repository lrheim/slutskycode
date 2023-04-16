

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

mname = {'lh122'; 'lh123'; 'lh126'; 'lh129'; 'lh130'};

mfrcat = cell(2, 2);
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
    sstates = [1, 4];
    cnt = 1;
    clear mfr stateRat stateGain
    for ifile = 1 : nfiles
        for ibin = 1 : 4
            for iunit = 1 : 2
                for istate = 1 : length(sstates)
                    unitIdx = v(ifile).units.clean(iunit, :);
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
            if imouse == 1      % CORRECT LH122
                tmp = nan(size(data, 1), 16);
                tmp(:, 1 : 4) = data(:, 1 : 4);
                tmp(:, 9 : 12) = data(:, 5 : 8);
                data = tmp;
            end

            mfrcat{istate, iunit} = [mfrcat{istate, iunit};...
                data];
        end
    end
    cell2nanmat(squeeze(stateRat(:, iunit)), 2);
    cell2nanmat(squeeze(stateGain(:, iunit)), 2);


end

mfrcat{1, 1}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MFR in states across mice
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% CHECK SESSION_LIST.XLSX

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
% get MFR vs. time across mice - baclofen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mname = {'lh96'; 'lh107'; 'lh122'};

fr = cell(length(mname), 2);
for imouse = 1 : length(mname)
    
    for iunit = 1 : 2
    
        % concatenate var from different sessions
        [expData, xData] = sessions_catVarTime('mname', mname{imouse},...
            'dataPreset', 'fr', 'graphics', false, 'dataAlt', iunit,...
            'basepaths', {}, 'xTicksBinsize', 6, 'markRecTrans', true);

        % remove nan
        expData(:, all(isnan(expData))) = [];
        
        % put in cell
        fr{imouse, iunit} = expData;

    end
end

% smooth each cell and than calc mean and std and smooth across population

iunit = 2;
npt = 31;
prismMat = cell2nanmat(fr(:, iunit));
prismMat = movmean(prismMat, npt, 1, 'omitnan');
nunits = sum(~isnan(prismMat'))';
xData = [1 / 60 : 1 / 60 : length(nunits) / 60];

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
    "E:\Data\lh130\lh130_230405_094750"];

% reload data
varsFile = ["fr"; "fr_bins"; "datInfo"; "session"; "units"];
varsName = ["fr"; "frBins"; "datInfo"; "session"; "units"];
xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
[v, ~] = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
    'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
    'xlsname', xlsname);
nfiles = length(basepaths);

% reanalyze
for ifile = 1 : nfiles

    % file
    basepath = basepaths{ifile};
    cd(basepath)
    [~, basename] = fileparts(basepath);

    % print progress
    fprintf('sessions_wrapper: working on session %d of %d, %s\n',...
        ifile, nfiles, basename)

    % add timebins to datInfo
    [timebins, timepnt] = metaInfo_timebins('reqPnt', 6 * 60 * 60, 'nbins', 4);
    timebins / 60 / 60

    % mfr by states in time bins
    frBins = fr_timebins('basepath', pwd, 'forceA', true, 'graphics', true,...
        'timebins', timebins, 'saveVar', true, 'sstates', [1, 4, 5]);

    % firing rate
    load([basename, '.spikes.cellinfo.mat'])
    winBL = [0 timepnt];
    fr = calc_fr(spikes.times, 'basepath', basepath,...
        'graphics', true, 'binsize', 60, 'saveVar', true, 'forceA', true,...
        'smet', 'none', 'winBL', winBL, 'winCalc', [0, Inf]);


end

% fr vs. time
iunit = 2;
[frMat, timeIdx] = alignFR2pnt('basepaths', basepaths, 'suFlag', true,...
    'dataType', 'strd', 'iunit', iunit, 'timeIdx', [0 0 0 0 0]);

% to prism
npnts = 13;
smooth(mean(frMat, 2), npnts);
smooth(std(frMat, [], 2) / sqrt(length(frMat)), npnts);
nunits = sum(~isnan(frMat)');

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




frBins = catfields([v(ifile).frBins(:)], 'catdef', 'cell')

frBins.states.mfr

