

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfg = as_loadConfig;
sstates = [1, 4];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% chronic mk801

mname = 'lh126';

varsFile = ["fr"; "sr"; "spikes"; "cell_metrics"; "sleep_states";...
    "datInfo"; "session"; "units"; "psd"; "ripp"];
varsName = ["fr"; "sr"; "spikes"; "cm"; "ss"; "datInfo"; "session";...
    "units"; "psd"; "ripp"];
xlsname = 'D:\Google Drive\PhD\Slutsky\Data Summaries\sessionList.xlsx';
[v, basepaths] = getSessionVars('mname', mname, 'varsFile', varsFile,...
    'varsName', varsName, 'pcond', ["tempflag"], 'ncond', [""],...
    'xlsname', xlsname);
nfiles = length(basepaths);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% organize data - spiking
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fr = [v(:).fr];
states = catfields([fr(:).states], 'catdef', 'cell', 'force', false);


% ORGANIZE: stateFr is a cell array (of states) where each cell is a mat of
% units (rows) x sessions (columns) depicting the MFR per unit
clear stateFr stateFrCell
iunit = 1; 
for istate = 1 : length(sstates)
    for ifile = 1 : nfiles

        unitIdx = v(ifile).units.clean(iunit, :);
        stateFrCell{ifile, istate} = states.mfr{ifile}(unitIdx, sstates(istate));

    end
    stateFr{istate} = cell2nanmat(stateFrCell(:, istate), 2);
end


% ORGANIZE: stateGain is a matrix of unit (rows) x session (columns)
% depicting the state gain factor for istate compared to AWAKE
clear stateGain
iunit = 1;
istate = 4;
for ifile = 1 : nfiles

    unitIdx = v(ifile).units.clean(iunit, :);
    stateGain{ifile} = states.gain{ifile}(istate, unitIdx);

end
stateGain = cell2nanmat(stateGain, 2);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% organize data - psd
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

psd = catfields([v(:).psd], 'catdef', 'cell', 'force', false);

% ORGANIZE: statePsd is a matrix of frequency (rows) x session (column)
% depicting the psd for the selected state
clear statePsd 
istate = 4;    
for ifile = 1 : nfiles

    statePsd(:, ifile) = squeeze(psd.psd{ifile}(1, istate, :));

end
statePsd = statePsd ./ sum(statePsd);
freq = psd.info.faxis{1};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% organize data - ripples
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

iunit = 1;
clear rippGain
for ifile = 1 : nfiles

    unitIdx = v(ifile).units.clean(iunit, :);
    rippMfr = v(ifile).ripp.spks.su.rippMap(unitIdx, :, :);
    rippMfr = squeeze(mean(mean(rippMfr, 2), 3));
    randMfr = v(ifile).ripp.spks.su.randMap(unitIdx, :, :);
    randMfr = squeeze(mean(mean(randMfr, 2), 3));    
    rippGain{ifile} = (rippMfr - randMfr) ./ (rippMfr + randMfr);

end
rippGain = cell2nanmat(rippGain, 2);

