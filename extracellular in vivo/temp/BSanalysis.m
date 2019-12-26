%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% tetrodes
ch = 5;
basepath = 'E:\Data\Dat\lh43';
[~, filename] = fileparts(basepath);
cd(basepath)
load([filename '.lfp.mat'])
fs = lfp.fs;
idx = 1 : 6000 * fs;
x = double(lfp.data(idx, ch));

% field
basepath = 'E:\Data\Others\DZ\Field\Acute recordings\Long recordings\WT\WT2';
cd(basepath)
filename = dir('*abf');
filename = filename.name;
[d, si, h] = abfload(filename, 'start', 0, 'stop', 'e', 'channels', 'a');
    


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delta power 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% filter in spectrum. no need to filter if spectrogram. 
% passband = [0 6];
% order = 6;
% type = 'butter';
% sig = filterLFP(x, 'type', type, 'fs', fs,...
%     'passband', passband, 'order', order, 'graphics', false);

% broad-band spectrogram
freq = logspace(0, 2, 100);
win = hann(2 ^ nextpow2(0.5 * fs));
[s, f, t, p] = spectrogram(x, win, length(win) / 2, freq, fs,...
    'yaxis', 'psd');

% integrate power over the delta band 
deltaf = [0.5 4];
[~, deltaidx] = min(abs(f - deltaf));
deltap = sum(p(deltaidx(1) : deltaidx(2), :), 1);

% z-score. this is a great way of comparing changes within a signal
deltaz = zscore(deltap);

figure
subplot(2, 1, 1)
surf(t, f, 10*log10(abs(p)), 'EdgeColor', 'none');
axis xy; 
axis tight; 
colormap(jet); 
view(0,90);
xlabel('Time (secs)');
colorbar;
ylabel('Frequency [Hz]');
set(gca, 'YScale', 'log')
subplot(2, 1, 2)
plot(t, deltaz)



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% burst suppression
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% params
winmax = 0.8 * fs;      % window for moving max        
binw = 0.15 * fs;       % bin width for std calculation
dist = 0.2 * fs;        % distance for removing adjacent peaks
thr = 1;                % threshold of detection

% std
s = movstd(double(x), binw);


figure,plot(s)

% threshold for bs separation is determined according to the bimodel
% distribution of std values
thr = sepBimodel('x', s, 'lognorm', true, 'graphics', true);


histogram(s)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% getBS 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

bs = getBS('sig', x, 'fs', lfp.fs, 'basepath', basepath,...
    'graphics', false, 'saveVar', false);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

figure
plot(lfp.timestamps(idx), bs.binary)
hold on
yyaxis right
plot(lfp.timestamps(idx), lfp.data(idx, ch))
xlim([idx(1), idx(1) + 300])

dur = diff(bs.stamps, 1, 2);
ibi = bs.stamps(2 : end, 1) - bs.stamps(1 : end - 1, 2);

histogram(log10(dur))

figure, plot(log10(ibi), '*')
