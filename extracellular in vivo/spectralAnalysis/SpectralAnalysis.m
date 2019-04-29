%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Filter LFP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

order = 4;
passband = 'gamma';
switch passband
    case 'delta'
        passband = [0 6];
        order = 8;
    case 'theta'
        passband = [4 10];
    case 'spindles'
        passband = [9 17];
    case 'gamma'
        passband = [30 80];
    case 'ripples'
        passband = [100 250];
    otherwise
        error('Unknown frequency band')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% find ripples
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

filtered = filterLFP(double(lfp.data(:, 1)), 'passband', [100 200]);

ripples = bz_FindRipples(lfp.data(:, 1), lfp.timestamps, 'EMGThres', 0.9, 'plottype', 1, 'show', 'on');
[maps,data,stats] = bz_RippleStats(filtered.data(:, 1),lfp.timestamps, ripples);
bz_PlotRippleStats(maps, data, stats)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calculate and plot spectrogram
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

frange = [1 128];
nf = 100;       
f = logspace(log10(frange(1)), log10(frange(2)), nf);
win = 1 * fs;
noverlap = 0.8 * fs;

% calculate
[spec, ~, t_FFT] = spectrogram(x, win, noverlap, f, fs);
spec = abs(spec)';

% plot
spectrogram(x, 'yaxis', win, noverlap, f, fs)
ax = gca;
ax.YScale = 'log';







