function plot_monoSyn(varargin)

% plot mono synaptic connection
% 
% INPUT:
%   basepath        path to recording {pwd}
%   spktimes        1 x 2 cell spike times [s]
%   units           1 x 2 numeric of unit idx
%   ccg2            2 x n numeric. 2nd ccg to plot. e.g. the deconvolved
%                   ccg from ccg_stg (lidor). if empty will be a very
%                   narrow stg. 
%   ccg2_tstamps    numeric vec of cch bins for ccg2
%   clr             2 element char. color for each cell
%   wv              2 x n numeric. mean waveform of units.
%   wv_std          2 x n numeric. std of units waveforms.
%   stg             numeric. spike transmission gain
%   fs              numeric. sampling frequency 
%   saveFig         logical {true}
%
% DEPENDENCIES:
%   CCG
%
% 10 jan 22 LH

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'spktimes', {}, @iscell);
addOptional(p, 'units', [], @isnumeric);
addOptional(p, 'ccg2', [], @isnumeric);
addOptional(p, 'ccg2_tstamps', [], @isnumeric);
addOptional(p, 'clr', 'kk', @ischar);
addOptional(p, 'wv', [], @isnumeric);
addOptional(p, 'wv_std', [], @isnumeric);
addOptional(p, 'stg', [], @isnumeric);
addOptional(p, 'fs', 10000, @isnumeric);
addOptional(p, 'saveFig', true, @islogical);

parse(p, varargin{:})
basepath        = p.Results.basepath;
spktimes        = p.Results.spktimes;
units           = p.Results.units;
ccg2            = p.Results.ccg2;
ccg2_tstamps    = p.Results.ccg2_tstamps;
clr             = p.Results.clr;
wv              = p.Results.wv;
wv_std          = p.Results.wv_std;
stg             = p.Results.stg;
fs              = p.Results.fs;
saveFig         = p.Results.saveFig;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% gather data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isempty(clr)
    clr = repmat('k', 1, 2);
end

% ccg 
ccg_bnsz = 0.0005;
ccg_dur = 0.1;
[ccg, ccg_tstamps] = CCG(spktimes,...
    [], 'binSize', ccg_bnsz,...
    'duration', ccg_dur, 'norm', 'rate', 'Fs', 1 / fs);
ccg_tstamps = ccg_tstamps * 1000;

% ccg2
if isempty(ccg2) || isempty(ccg2_tstamps)
    ccg2_bnsz = 0.0001;
    ccg2_dur = 0.02;
    [ccg2, ccg2_tstamps] = CCG(spktimes,...
        [], 'binSize', ccg2_bnsz,...
        'duration', ccg2_dur, 'norm', 'rate', 'Fs', 1 / fs);
    ccg2_tstamps = ccg2_tstamps * 1000;
    ccg2 = squeeze(ccg2(:, 1, 2));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

setMatlabGraphics(false)
fh = figure;

% acg narrow 1
subplot(2, 3, 1)
bh = bar(ccg_tstamps,...
    squeeze(ccg(:, 1, 1)), 'BarWidth', 1);
ylabel('Rate [Hz]')
xlabel('Time [ms]')
bh.FaceColor = clr(1);
bh.EdgeColor = 'none';
box off
axis tight
title(sprintf('Unit #%d (Presynaptic)', units(1)))

% ccg 
subplot(2, 3, 2)
bh = bar(ccg_tstamps,...
    squeeze(ccg(:, 1, 2)), 'BarWidth', 1);
hold on
plot([0, 0], ylim, '--k')
ylabel('Rate [Hz]')
xlabel('Time [ms]')
bh.FaceColor = 'k';
bh.EdgeColor = 'none';
box off
axis tight

% acg narrow 2
subplot(2, 3, 3)
bh = bar(ccg_tstamps,...
    squeeze(ccg(:, 2, 2)), 'BarWidth', 1);
ylabel('Rate [Hz]')
xlabel('Time [ms]')
bh.FaceColor = clr(2);
bh.EdgeColor = 'none';
box off
axis tight
title(sprintf('Unit #%d (Postsynaptic)', units(2)))

% ccg super narrow 
subplot(2, 3, 5)
bh = bar(ccg2_tstamps, ccg2, 'BarWidth', 1);
hold on
plot([0, 0], ylim, '--k')
ylabel('Rate [Hz]')
xlabel('Time [ms]')
bh.FaceColor = 'k';
bh.EdgeColor = 'none';
box off
axis tight
title(sprintf('STG = %.2f', stg))

if ~isempty(wv)
    
    % waveform 1
    subplot(2, 3, 4)
    x_val = [1 : size(wv, 2)] / fs * 1000;
    plot(x_val, wv(1, :), clr(1), 'LineWidth', 2)
    if ~isempty(wv_std)
        patch([x_val, flip(x_val)], [wv(1, :) + wv_std(1, :), flip(wv(1, :) - wv_std(1, :))],...
            clr(1), 'EdgeColor', 'none', 'FaceAlpha', .2, 'HitTest', 'off')
    end
    xlabel('Time [ms]')
    ylabel('Voltage [mV]')
    
    % waveform 2
    subplot(2, 3, 6)
    x_val = [1 : size(wv, 2)] / fs * 1000;
    plot(x_val, wv(2, :), clr(2), 'LineWidth', 2)
    if ~isempty(wv_std)
        patch([x_val, flip(x_val)], [wv(2, :) + wv_std(2, :), flip(wv(2, :) - wv_std(2, :))],...
            clr(2), 'EdgeColor', 'none', 'FaceAlpha', .2, 'HitTest', 'off')
    end
    xlabel('Time [ms]')
    ylabel('Voltage [mV]')
    
    % save
    if saveFig
        figpath = fullfile(basepath, 'graphics');
        figname = fullfile(figpath, sprintf('monoSyn_%d_%d', units));
        export_fig(figname, '-jpg', '-transparent', '-r300')
    end
    
end

end

% EOF