% select mouse
i = 1;      % grp
j = 11;     % mouse

% params
basepath{1} = 'E:\Data\Others\DZ\IIS\WT';
basepath{2} = 'E:\Data\Others\DZ\IIS\APPPS1';
basepath{3} = 'E:\Data\Others\DZ\IIS\APPKi';
basepath{4} = 'E:\Data\Others\DZ\IIS\FADx5';
cd(basepath{i})
filename = dir('*.abf');
files = natsort({filename.name});
nfiles = 1 : length(files);
[~, grpname] = fileparts(basepath{i});
[~, basename] = fileparts(files{nfiles(j)});

fs = 1250;
binsize = (2 ^ nextpow2(30 * fs));
smf = 7;
marg = 0.05;
thr = [0 0];
ch = 1;

% load lfp
lfp = getLFP('basepath', basepath{i}, 'ch', ch, 'chavg', {},...
    'fs', 1250, 'interval', [0 inf], 'extension', 'abf', 'pli', true,...
    'savevar', false, 'force', false, 'basename', basename);
sig = double(lfp.data(:, ch));

% load iis
iis = getIIS('sig', sig, 'fs', fs, 'basepath', basepath{i},...
    'graphics', false, 'saveVar', false, 'binsize', binsize,...
    'marg', marg, 'basename', basename, 'thr', thr, 'smf', 7,...
    'saveFig', false, 'forceA', false, 'spkw', false, 'vis', false);

% load bs
vars = {'std', 'max', 'sum'};
bs = getBS('sig', sig, 'fs', fs, 'basepath', basepath{i}, 'graphics', false,...
    'saveVar', false, 'binsize', 0.5, 'BSRbinsize', binsize, 'smf', smf,...
    'clustmet', 'gmm', 'vars', vars, 'basename', basename,...
    'saveFig', false, 'forceA', false, 'vis', false);

% load delta
load([grpname '_as.mat'])
load([basename '.ep.mat'])

if graphics    
    fh = figure('Visible', 'on');
    set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
    suptitle('WT1')
    
    % spectrogram
    sb1 = subplot(8, 1, 1);
    specBand('sig', sig, 'graphics', true, 'binsize', binsize, 'smf', smf, 'normband', true);
    ylim([0 100])
    title('')
    
    % bsr
    sb2 = subplot(8, 1, 2);
    plot(bs.cents / fs / 60, bs.bsr, 'k', 'LineWidth', 1)
    hold on
    ylim([0 1])
    Y = ylim;
    set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
        'Color', 'none', 'XColor', 'none')
    box off
    ylabel('BSR')
    fill([ep.deep_stamps fliplr(ep.deep_stamps)]' / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
        'b', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
    fill([ep.sur_stamps fliplr(ep.sur_stamps)]' / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
        'g', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
    
    % delta
    sb3 = subplot(8, 1, 3);
    plot(bs.cents / fs / 60, ep.dband, 'k', 'LineWidth', 1)
    hold on
    set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
        'Color', 'none', 'XColor', 'none')
    box off
    ylabel('Delta')
    ylim([0 1])
    Y = ylim;
    fill([ep.deep_stamps fliplr(ep.deep_stamps)]' / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
        'b', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
    fill([ep.sur_stamps fliplr(ep.sur_stamps)]' / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
        'g', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
    legend({'Deep anesthesia', 'Surgical anesthesia'}) 
    
    % raw
    sb4 = subplot(8, 1, 4);
    plot(lfp.timestamps / 60, sig, 'k', 'LineWidth', 1)
    set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
        'Color', 'none', 'XColor', 'none')
    box off
    ylabel('LFP [mV]')
    
    % zoom in
    sb5 = subplot(8, 1, 5);
    minmarg = 1.5;
    midsig = round(length(sig) / 2);
    idx = round(midsig - minmarg * fs * 60 : midsig + minmarg * fs * 60);
    idx2 = iis.peakPos > idx(1) & iis.peakPos < idx(end);
    plot(lfp.timestamps(idx) / 60, sig(idx), 'k')
    axis tight
    hold on
    x = xlim;
    plot(x, [iis.thr(2) iis.thr(2)], '--r')
    scatter(iis.peakPos(idx2) / fs / 60,...
        iis.peakPower(idx2), '*');
    bsstamps = RestrictInts(bs.stamps, [idx(1) idx(end)]);
    Y = ylim;
    if ~isempty(bsstamps)
        fill([bsstamps fliplr(bsstamps)] / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
            'k', 'FaceAlpha', 0.25,  'EdgeAlpha', 0);
    end
    ylabel('Voltage [mV]')
    xlabel('Time [m]')
    xticks([ceil(midsig / fs / 60 - minmarg), floor(midsig / fs / 60 + minmarg)])
    set(gca, 'TickLength', [0 0])
    box off
    title('IIS')    
    
    
    sb1 = subplot(3, 2, 1 : 2);
    plot(tstamps, sig, 'k')
    axis tight
%     ylim([-1 2])
    hold on
    plot(xlim, [iis.thr(2) iis.thr(2)], '--r')
    ylabel('Voltage [mV]')
    yyaxis right
    p1 = plot(iis.cents / fs / 60, iis.rate, 'r', 'LineWidth', 3);
    if ~isempty(p1)
        p1.Color(4) = 0.3;
    end
    ylim([0 1])
    ylabel('Rate [spikes / bin]')
    legend({'Raw', 'IIS thr', 'IIS rate'}, 'Location', 'northwest')
    axis tight
    set(gca, 'TickLength', [0 0])
    box off
    
    % bsr and delta
    sb2 = subplot(3, 2, 3 : 4);
    plot(bs.cents / fs / 60, bs.bsr, 'k', 'LineWidth', 2)
    hold on
    plot(tband / 60, ep.dband, 'b', 'LineWidth', 2)
    legend({'BSR', 'Delta'})
    ylim([0 1])
    Y = ylim;
    if ~isempty(ep.deep_stamps)
        fill([ep.deep_stamps fliplr(ep.deep_stamps)]' / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
            'b', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
    end
    if ~isempty(ep.sur_stamps)
        fill([ep.sur_stamps fliplr(ep.sur_stamps)]' / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
            'g', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
    end
    xlabel('Time [m]')
    ylabel('[a.u.]')
    axis tight
    set(gca, 'TickLength', [0 0])
    box off
    title('Anesthesia States')
    
    % zoom in raw, bs, and iis
    subplot(3, 2, 5);
    minmarg = 1.5;
    midsig = round(length(sig) / 2);
    idx = round(midsig - minmarg * fs * 60 : midsig + minmarg * fs * 60);
    idx2 = iis.peakPos > idx(1) & iis.peakPos < idx(end);
    plot(tstamps(idx), sig(idx), 'k')
    axis tight
    hold on
    x = xlim;
    plot(x, [iis.thr(2) iis.thr(2)], '--r')
    scatter(iis.peakPos(idx2) / fs / 60,...
        iis.peakPower(idx2), '*');
    bsstamps = RestrictInts(bs.stamps, [idx(1) idx(end)]);
    Y = ylim;
    if ~isempty(bsstamps)
        fill([bsstamps fliplr(bsstamps)] / fs / 60, [Y(1) Y(1) Y(2) Y(2)],...
            'k', 'FaceAlpha', 0.25,  'EdgeAlpha', 0);
    end
    ylabel('Voltage [mV]')
    xlabel('Time [m]')
    xticks([ceil(midsig / fs / 60 - minmarg), floor(midsig / fs / 60 + minmarg)])
    set(gca, 'TickLength', [0 0])
    box off
    title('IIS')    
    
    % iis waveforms
    if ~isempty(iis.wv)
        subplot(3, 2, 6)
        plot(wvstamps * 1000, iis.wv)
        ylabel('Voltage [mV]')
        xlabel('Time [ms]')
        axis tight
        xticks([-marg, 0, marg] * 1000);
        set(gca, 'TickLength', [0 0])
        box off
        title('IIS waveform')       
        
        % mean + std waveform
        axes('Position',[.571 .11 .15 .1])
        box on
        stdshade(iis.wv, 0.5, 'k', wvstamps)
        axis tight
        set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
            'XColor', 'none', 'YColor', 'none', 'Color', 'none')
        title(sprintf('n = %d', size(iis.wv, 1)));
        box off
    end
    
    linkaxes([sb1, sb2], 'x');
    
    if saveFig
        figname = [basename];
        export_fig(figname, '-tif', '-transparent')
        % savePdf(figname, basepath, ff)
    end  
end