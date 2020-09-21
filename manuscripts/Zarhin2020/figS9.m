% figS9 in Zarhin et al., 2020

close all
force = false;
saveFig = true;

grppath{1} = 'G:\Data\Processed\Manuscripts\Zarhin2020\IIS\WT\New analyis';
grppath{2} = 'G:\Data\Processed\Manuscripts\Zarhin2020\IIS\APPPS1\New analysis';

% select mouse (according to file order in path)
i_wt1 = 7;
i_wt2 = 6;
i_app1 = 27;
i_app2 = 5;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if force
    
    % load wt1 data (deep)
    cd(grppath{1})
    filename = dir('*.lfp.*');
    files = natsort({filename.name});
    nfiles = 1 : length(files);
    [~, basename] = fileparts(files{nfiles(i_wt1)});
    [~, basename] = fileparts(basename);
    [bs, iis, ep] = aneStates('ch', 1, 'basepath', grppath{1},...
        'basename', basename, 'graphics', false,...
        'saveVar', false, 'saveFig', false, 'forceA', false,...
        'binsize', 30, 'smf', 7, 'thrMet', 1);
    load([fullfile(grppath{1}, basename) '.lfp.mat'])
    lfp1 = lfp;
    bs1 = bs;
    iis1 = iis;
    ep1 = ep;
    
    % load wt2 data (surgical)
    cd(grppath{1})
    filename = dir('*.lfp.*');
    files = natsort({filename.name});
    nfiles = 1 : length(files);
    [~, basename] = fileparts(files{nfiles(i_wt2)});
    [~, basename] = fileparts(basename);
    [bs, iis, ep] = aneStates('ch', 1, 'basepath', grppath{1},...
        'basename', basename, 'graphics', false,...
        'saveVar', false, 'saveFig', false, 'forceA', false,...
        'binsize', 30, 'smf', 7, 'thrMet', 1);
    load([fullfile(grppath{1}, basename) '.lfp.mat'])
    lfp2 = lfp;
    bs2 = bs;
    iis2 = iis;
    ep2 = ep;
    
    % load apps1 data (deep)
    cd(grppath{2})
    filename = dir('*.lfp.*');
    files = natsort({filename.name});
    nfiles = 1 : length(files);
    [~, basename] = fileparts(files{nfiles(i_app1)});
    [~, basename] = fileparts(basename);
    [bs, iis, ep] = aneStates('ch', 1, 'basepath', grppath{2},...
        'basename', basename, 'graphics', false,...
        'saveVar', false, 'saveFig', false, 'forceA', false,...
        'binsize', 30, 'smf', 7, 'thrMet', 1);
    load([fullfile(grppath{2}, basename) '.lfp.mat'])
    lfp3 = lfp;
    bs3 = bs;
    iis3 = iis;
    ep3 = ep;
    
    % load apps1 data (surgical)
    cd(grppath{2})
    filename = dir('*.lfp.*');
    files = natsort({filename.name});
    nfiles = 1 : length(files);
    [~, basename] = fileparts(files{nfiles(i_app2)});
    [~, basename] = fileparts(basename);
    [bs, iis, ep] = aneStates('ch', 1, 'basepath', grppath{2},...
        'basename', basename, 'graphics', false,...
        'saveVar', false, 'saveFig', false, 'forceA', false,...
        'binsize', 30, 'smf', 7, 'thrMet', 1);
    load([fullfile(grppath{2}, basename) '.lfp.mat'])
    lfp4 = lfp;
    bs4 = bs;
    iis4 = iis;
    ep4 = ep;
    
    % bs classification
    fs = lfp.fs;
    binsize = 2 ^ nextpow2(0.5 * fs);   % for pc1
    
    ibins = [1 : binsize : length(lfp3.data)];
    ibins(end) = length(lfp3.data);
    
    % divide signal to bins
    sigre = lfp3.data(1 : end - (mod(length(lfp3.data), binsize) + binsize));
    sigmat = reshape(sigre, binsize, (floor(length(lfp3.data) / binsize) - 1));
    
    % last bin
    siglastbin = lfp3.data(length(sigre) + 1 : length(lfp3.data));
    
    stdvec = std(sigmat);
    stdvec = [stdvec, std(siglastbin)];
    maxvec = max(abs(sigmat));
    maxvec = [maxvec, max(abs(siglastbin))];
    freq = logspace(0, 2, 100);
    win = hann(binsize);
    [~, fff, ttt, pband] = spectrogram(lfp3.data, win, 0, freq, fs, 'yaxis', 'psd');
    pband = 10 * log10(abs(pband));
    [~, pc1] = pca(pband', 'NumComponents', 1);
    
    % concatenate and lognorm
    varmat = [stdvec; maxvec];
    if size(varmat, 1) < size (varmat, 2)
        varmat = varmat';
    end
    varmat = log10(varmat);
    varmat = [varmat, pc1];
    
    options = statset('MaxIter', 500);
    gm = fitgmdist(varmat, 2,...
        'options', options, 'Start', 'plus', 'Replicates', 50);
    % cluster
    [gi, ~, ~, ~, mDist] = cluster(bs3.gm, varmat);
    
    options = statset('MaxIter', 50);
    gm = fitgmdist(varmat(:, [1, 3]), 2,...
        'options', options, 'Start', 'plus', 'Replicates', 50);
    
    % group data
    basepath = fileparts(fileparts(grppath{1}));
    load(fullfile(basepath, 'as.mat'))
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% general params
fh = figure('Visible', 'on');
set(gcf, 'units','normalized','outerposition',[0 0 1 1]);

Y = sort([1 -1]); % ylim for raw
YY = sort([0.5 -1]); % ylim for zoom
binsize = (2 ^ nextpow2(fs * 1));
smf = 15;
marg = 0.05;
minmarg = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% wt mouse deep

midsig = 23;
idx1 = 19 * fs * 60 : 24 * fs * 60;
c = 2;
ncol = 4;
plotColumn(idx1, midsig, lfp1, bs1, iis1, ep1, c, ncol, 'WT - deep')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% wt mouse surgical

midsig = 24.8;
idx1 = 24 * fs * 60 : 29 * fs * 60;
c = 1;
ncol = 4;
plotColumn(idx1, midsig, lfp2, bs2, iis2, ep2, c, ncol, 'WT - surgical')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% app mouse deep
midsig = 33.5;
idx1 = 29 * fs * 60 : 34 * fs * 60;
c = 4;
ncol = 4;
plotColumn(idx1, midsig, lfp3, bs3, iis3, ep3, c, ncol, 'APP/PS1 - deep')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% app mouse surgical
midsig = 67;
idx1 = 66 * fs * 60 : 71 * fs * 60;
c = 3;
ncol = 4;
plotColumn(idx1, midsig, lfp4, bs4, iis4, ep4, c, ncol, 'APP/PS1 - surgical')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bs identification

subplot(5, 4, [13, 14, 17, 18])
gscatter(varmat(:, 1), varmat(:, 3), gi, 'rk', '.', 5);
axis tight
hold on
gmPDF = @(x1, x2)reshape(pdf(gm, [x1(:) x2(:)]), size(x1));
ax = gca;
fcontour(gmPDF, [ax.XLim ax.YLim], 'HandleVisibility', 'off')
xlabel(['std [log10(\sigma)]'])
ylabel('PC1 [a.u.]')
legend({'Burst', 'Suppression'}, 'Location', 'northwest')
set(gca, 'TickLength', [0 0])
box off

histbins = 40;
% std histograg
% axes('Position', [.627 .11 .07 .07])
axes('Position',[.442 .11 .05 .05])
box on
h = histogram(varmat(:, 1), histbins, 'Normalization', 'Probability');
h.EdgeColor = 'none';
h.FaceColor = 'k';
h.FaceAlpha = 1;
title(['std'])
axis tight
set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
    'YColor', 'none', 'Color', 'none')
box off

% max histogram
axes('Position',[.442 .18 .05 .05])
% axes('Position',[.627 .2 .07 .07])
box on
h = histogram(varmat(:, 2), histbins, 'Normalization', 'Probability');
h.EdgeColor = 'none';
h.FaceColor = 'k';
h.FaceAlpha = 1;
title(['max'])
axis tight
set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
    'YColor', 'none', 'Color', 'none')
box off

% PC1 histogram
axes('Position',[.389 .11 .05 .05])
% axes('Position',[.549 .11 .07 .07])
box on
h = histogram(varmat(:, 3), histbins, 'Normalization', 'Probability');
h.EdgeColor = 'none';
h.FaceColor = 'k';
h.FaceAlpha = 1;
title(['PC1'])
axis tight
set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
    'YColor', 'none', 'Color', 'none')
box off

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% aneStats

% All groups
gidx = [ones(1, 30), ones(1, 30) * 2,...
    ones(1, 30) * 3, ones(1, 30) * 4];
% data = as.deepFraction;
c2 = 'kr';

% WT and APPPS1 only
gidx = [ones(1, 30), ones(1, 30) * 2];
% data = as.deepFraction(:, 1 : 2);
data = cell2nanmat(as.bsrDeep(:, 1 : 2));
% data = as.bsr

subplot(5, 4, [15, 16, 19, 20])
boxplot(data, gidx, 'PlotStyle', 'traditional',...
    'BoxStyle', 'outline', 'Color', c2, 'notch', 'off')
hold on
gscatter(gidx, [data(:)], gidx, c2)
legend off
xlabel('')
xticklabels({'WT', 'APPPS1', 'APPKi', 'FADx5'})
% ylabel('Deep anesthesia duration [% total]')
ylabel('BSR in deep anaesthesia')
ylim([0 1])
box off
set(gca, 'TickLength', [0 0])
[h, p] = ttest2(data(:, 1), data(:, 2));
sigstar({[1, 2]}, p, 1);
% sigstar({[1, 3], [1, 4], [2, 4], [2, 3]}, [0.05, 0.01, 0.01, 0.05], 1);

if saveFig
    figname = fullfile(basepath, 'figS9');
%     export_fig(figname, '-tif', '-transparent', '-r300')
%     export_fig(figname, '-pdf')
%     savePdf('figS9', basepath, fh)
 print(fh, figname, '-dpdf', '-bestfit'); 
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plot column

