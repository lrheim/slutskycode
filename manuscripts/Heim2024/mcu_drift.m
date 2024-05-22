
% groups
queryStr = ["wt_bsl"; "wt_bac2"];

% general params
varsFile = ["fr"; "units"];
varsName = ["fr"; "units"];

clear drft d dgrp
for igrp = 1 : length(queryStr)

    % load data
    basepaths = mcu_sessions(queryStr{igrp});
    v = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
        'varsName', varsName, 'pcond', ["tempflag"]);
    nfiles = length(basepaths);

    % go over files
    for ifile = 1 : nfiles

        % file params
        basepath = basepaths{ifile};
        cd(basepath)
        [~, basename] = fileparts(basepath);

        drft(ifile) = drift_file(basepath, false);

    end

    d(igrp) = catfields(drft, 'addim');

end
dgrp = catfields(d, 'addim');

% dimensions of dgrp are (example m_corr):
% data x unit x state x file x grp

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ulabel = ["RS"; "FS"];
slabel = ["Full Recordings"; "AW"; "NREM"];

setMatlabGraphics(true)
fh = figure;
set(fh, 'WindowState', 'maximized');
tlayout = [2, 3];
th = tiledlayout(tlayout(1), tlayout(2));
th.TileSpacing = 'tight';
th.Padding = 'none';
set(fh, 'DefaultAxesFontSize', 16);

yLimit = [0, round(max(dgrp.drate, [], 'all') * 100) / 100];
tbias = 1;
for iunit = 1 : 2
    for istate = 1
        axh = nexttile(th, tbias, [1, 1]); cla; hold on
        dataMat = squeeze(dgrp.drate(iunit, istate, :, :));
        plot_boxMean('dataMat', dataMat, 'plotType', 'bar',...
            'allPnts', false, 'axh', axh)
        plot(axh, [1, 2], dataMat)

        ylim(yLimit)            
        ylabel(sprintf('%s Drift Rate [1 / h]', ulabel(iunit)))
        title(axh, slabel(istate))
        tbias = tbias + 1;
    end
end


% data for prism
tmp = squeeze(dgrp.drate(:, 1, :, :));
prismData = reshape(tmp, 2, 10)

