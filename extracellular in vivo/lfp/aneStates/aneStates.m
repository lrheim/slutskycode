
% analyze anesthesia states. Is essentialy a wrapper for analysis at the
% mouse (aneStates_m) and group (aneStates_g) level.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath{1} = 'E:\Data\Field\IIS\APPPS1';
basepath{2} = 'E:\Data\Others\DZ\IIS\APPPS1';
basepath{3} = 'E:\Data\Others\DZ\IIS\APPKi';
basepath{4} = 'E:\Data\Others\DZ\IIS\FADx5';
rm = cell(4, 1);

forceA = false;
forceL = false;
saveFig = true;
graphics = true;
saveVar = true;
ch = 1;
smf = 7;
fs = 1250;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% group data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i = 1 : length(basepath)
       
    as{i} = aneStates_g('basepath', basepath{i}, 'rm', rm{i},...
        'graphics', graphics, 'saveVar', saveVar,...
        'saveFig', saveFig, 'forceA', forceA);
    
    nspks{i} = as{i}.nspks;
    deep_nspks{i} = as{i}.deep_nspks;
    sur_nspks{i} = as{i}.sur_nspks;
    recDur{i} = as{i}.recDur;
    deepDur{i} = as{i}.deepDur;
    surDur{i} = as{i}.surDur;
    thr{i} = as{i}.thr;
    grp{i} = as{i}.grp;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arrange to prism
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

maxmice = 27;
mat = cellfun(@(x)[x(:); NaN(maxmice-length(x), 1)], deep_nspks,...
    'UniformOutput', false);
deep_nspks = cell2mat(mat);

mat = cellfun(@(x)[x(:); NaN(maxmice-length(x), 1)], sur_nspks,...
    'UniformOutput', false);
sur_nspks = cell2mat(mat);

mat = cellfun(@(x)[x(:); NaN(maxmice-length(x), 1)], nspks,...
    'UniformOutput', false);
nspks = cell2mat(mat);

mat = cellfun(@(x)[x(:); NaN(maxmice-length(x), 1)], thr,...
    'UniformOutput', false);
thr = cell2mat(mat);

mat = cellfun(@(x)[x(:); NaN(maxmice-length(x), 1)], recDur,...
    'UniformOutput', false);
recDur = cell2mat(mat);
recDur = recDur / fs / 60;

mat = cellfun(@(x)[x(:); NaN(maxmice-length(x), 1)], deepDur,...
    'UniformOutput', false);
deepDur = cell2mat(mat);
deepDur = deepDur / fs / 60;

mat = cellfun(@(x)[x(:); NaN(maxmice-length(x), 1)], surDur,...
    'UniformOutput', false);
surDur = cell2mat(mat);
surDur = surDur / fs / 60;

surFraction = surDur ./ recDur;
deepFraction = deepDur ./ recDur;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

recmean = cellfun(@mean, recDur);
bsmean = cellfun(@mean, bsDur);
bmean = cellfun(@mean, bDur);

c = [1 0 0; 1 0 1; 0 0 1; 0 1 1];
c2 = 'rmbc';
gidx = [ones(1, length(bsDur{1})), ones(1, length(bsDur{2})) * 2,...
    ones(1, length(bsDur{3})) * 3, ones(1, length(bsDur{4})) * 4];

if graphics
    
    figure
    set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
    
    % short recordings
    subplot(3, 4, 1 : 2)
    hold on
    for i = [1, 2]
        stdshade(as{i}.iis, 0.1, c2(i), as{i}.t / fs / 60)
    end
    axis tight
    ylabel('IIS Rate [spikes / bin]')
    xlim([1 50])
    box off
    set(gca, 'TickLength', [0 0])
    title('Short Recordings')
    
    % long recordings
    subplot(3, 4, 5 : 6)
    hold on
    for i = [3, 4]
        stdshade(as{i}.iis, 0.1, c2(i), as{i}.t / fs / 60)
    end
    axis tight
    ylabel('IIS Rate [spikes / bin]')
    xlabel('Time [m]')
    xlim([1 100])
    box off
    set(gca, 'TickLength', [0 0])
    title('Long Recordings')
      
    % IIS total
    subplot(3, 4, 3)
    boxplot([nspks{:}] ./ ([recDur{:}] / fs / 60), gidx,...
        'BoxStyle', 'outline', 'Color', c2, 'notch', 'off')
    hold on
    gscatter(gidx, [nspks{:}] ./ ([recDur{:}] / fs / 60), gidx, c2)
    legend off
    xlabel('')
    ylabel('IIS Rate [spikes / bin]')
    xticklabels(grp)
    title('IIS total')
    box off
    set(gca, 'TickLength', [0 0])
    
    % IIS in BS 
    subplot(3, 4, 7)
    boxplot([nspksBS{:}] ./ ([bsDur{:}] / fs / 60), gidx,...
        'BoxStyle', 'outline', 'Color', c2, 'notch', 'off')
    hold on
    gscatter(gidx, [nspksBS{:}] ./ ([bsDur{:}] / fs / 60), gidx, c2)
    legend off
    xlabel('')
    ylabel('IIS Rate [spikes / bin]')
    xticklabels(grp)
    title('IIS in BS')
    box off
    set(gca, 'TickLength', [0 0])
    
    % IIS in B
    subplot(3, 4, 11)
    boxplot([nspksB{:}] ./ ([bDur{:}] / fs / 60), gidx,...
        'BoxStyle', 'outline', 'Color', c2, 'notch', 'off')
    hold on
    gscatter(gidx, [nspksB{:}] ./ ([bDur{:}] / fs / 60), gidx, c2)
    legend off
    xlabel('')
    ylabel('IIS Rate [spikes / bin]')
    xticklabels(grp)
    title('IIS in B')
    box off
    set(gca, 'TickLength', [0 0])

    % Duration total
    subplot(3, 4, 4)
    boxplot([recDur{:}] / fs / 60, gidx,...
        'BoxStyle', 'outline', 'Color', c2, 'notch', 'off')
    hold on
    gscatter(gidx, [recDur{:}] / fs / 60, gidx, c2)
    legend off
    xlabel('')
    ylabel('Duration [m]')
    xticklabels(grp)
    title('Duration Total')
    box off
    set(gca, 'TickLength', [0 0])
    
    % Duration BS
    subplot(3, 4, 8)
    boxplot(([bsDur{:}] / fs / 60) ./ ([recDur{:}] / fs / 60), gidx,...
        'BoxStyle', 'outline', 'Color', c2, 'notch', 'off')
    hold on
    gscatter(gidx, ([bsDur{:}] / fs / 60) ./ ([recDur{:}] / fs / 60), gidx, c2)
    legend off
    xlabel('')
    ylabel('BS / total')
    xticklabels(grp)
    title('Duration of BS')
    box off
    set(gca, 'TickLength', [0 0])
    
    % Duration B
    subplot(3, 4, 12)
    boxplot(([bDur{:}] / fs / 60) ./ ([recDur{:}] / fs / 60), gidx,...
        'BoxStyle', 'outline', 'Color', c2, 'notch', 'off')
    hold on
    gscatter(gidx, ([bDur{:}] / fs / 60) ./ ([recDur{:}] / fs / 60), gidx, c2)
    legend off
    xlabel('')
    ylabel('B / total')
    xticklabels(grp)
    title('Duration of B')
    box off
    set(gca, 'TickLength', [0 0])
    
    % duration bar
    subplot(3, 4, 9)
    b = bar(([bsmean; bmean; recmean]' / fs / 60), 'stacked',...
        'FaceColor', 'flat');
    for i = 1 : 4
        b(1).CData(i, :) = c(i, :) + 0.8;
        b(2).CData(i, :) = c(i, :) + 0.4;
        b(3).CData(i, :) = c(i, :);
    end
    axis tight
    xticklabels(grp)
    set(gca,'TickLabelInterpreter','none')
    legend({'0.3 < BSR < 0.8', 'BSR < 0.3', 'BSR > 0.8'})
    ylabel('Duration [m]')
    title('Duration')
    box off
    set(gca, 'TickLength', [0 0])
    
    % threshold bar
    subplot(3, 4, 10)
    boxplot([thr{:}], gidx, 'PlotStyle', 'traditional',...
        'BoxStyle', 'outline', 'Color', c2, 'notch', 'off')
    hold on
    gscatter(gidx, [thr{:}], gidx, c2)
    legend off
    xlabel('')
    xticklabels(grp)
    ylabel('Threshold [mV]')
    title('Threshold')
    box off
    set(gca, 'TickLength', [0 0])
    
    if saveFig
        figname = ['summary'];
        export_fig(figname, '-tif', '-transparent')
        % savePdf(figname, basepath, ff)
    end
end



