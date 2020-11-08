function getSpkTimesWh(varargin)

% detects spikes from whitened data. based on ks functions, specifically
% isloated_peaks_new.

% INPUT:
%   basepath    string. path to recording folder where temp_wh.dat exists {pwd} 
%   fs          numeric. sampling frequency [hz]{20000}
%   nchans      numeric. number of channels in dat file.
%   spkgrp      array where each cell is the electrodes for a spike group. 
%   saveVar     logical. save output {true}
%
% DEPENDENCIES
%
% TO DO LIST:
%   # there is a ~500 ms delay between the file ns and as plotted here
% 
% 01 nov 20 LH      

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic;

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'fs', 20000, @isnumeric);
addOptional(p, 'nchans', 35, @isnumeric);
addOptional(p, 'spkgrp', {}, @iscell);
addOptional(p, 'saveVar', true, @islogical);

parse(p, varargin{:})
basepath    = p.Results.basepath;
fs          = p.Results.fs;
nchans      = p.Results.nchans;
spkgrp      = p.Results.spkgrp;
saveVar     = p.Results.saveVar;

chunksize = 2048 ^ 2 + 64;      % from runKS
nchansWh = length([spkgrp{:}]);
saveVar = true;

% constants
loc_range = [6 max(size(cell2nanmat(spkgrp), 1))];  % for running minimum (dim 1 - sample; dim 2 - channel] 
scaleproc = 200;    % conversion back from unit variance to voltage
thr = -4;           % spike threshold in standard deviations {-6}
dt = 8;             % dead time between spikes [samples]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% detection
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic

% get file
cd(basepath)
[~, basename] = fileparts(basepath);
fraw = dir([basename '.dat']);
fwh = dir('*temp_wh.dat');

% arrange batches
nbytes = class2bytes('int16');          % size of one data point in bytes
nsamps = fraw.bytes / nbytes / nchans;  % length of raw dat [samples]
chunks = n2chunks('n', nsamps, 'chunksize', chunksize, 'clip', []);
nchunks = size(chunks, 1);

% memory map to temp_wh.dat
m = memmapfile(fwh.name, 'Format', {'int16' [nchansWh nsamps] 'mapped'});
d = m.data;

% initialize
spktimes = cell(1, length(spkgrp));
for i = 1 : nchunks          
    
    % print progress
    if i ~= 1
        fprintf(repmat('\b', 1, length(txt)))
    end
    txt = sprintf('working on chunk %d / %d', i, nchunks);
    fprintf(txt)
        
    for ii = 1 : length(spkgrp)
        % load data, move to GPU and scale back to unit variance
        wh = d.mapped(spkgrp{ii}, chunks(i, 1) : chunks(i, 2));        
        wh = gpuArray(wh');
        wh = single(wh);
        wh = wh / scaleproc;
        
        % moving minimum across channels and samples 
        smin = my_min(wh, loc_range, [1, 2]);
        
        % peaks are samples that achieve this local minimum AND have
        % negativities less than a preset threshold
        crossings = wh < smin + 1e-5 & wh < thr;
        
        [samp, ch, amp] = find(crossings .* wh); % find the non-zero peaks, and take their amplitudes 
        [samp, ia] = sort(gather(samp + chunks(i, 1) - 1));
        ch = gather(ch(ia));
        amp = gather(amp(ia));
                
        % if two spikes are closer than dt samples, keep larger one. this
        % complemants the local minimum in cases where the raw peak is wide
        % such that more than one sample reaches the local minimum.
        while any(diff(samp) < dt)
            idx = find(diff(samp) <= dt);
            idx2 = amp(idx) > amp(idx + 1);
            idx3 = sort([idx(idx2); idx(~idx2) + 1]);
            amp(idx3) = [];
            samp(idx3) = [];
            ch(idx3) = [];
        end        
        spktimes{ii} = [spktimes{ii}; [samp spkgrp{ii}(ch)']];       
    end
end

fprintf('\nthat took %.2f minutes\n', toc / 60)

% save variable
if saveVar
    save(fullfile(basepath, [basename '.spktimes.mat']), 'spktimes')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if graphics
   
    % ---------------------------------------------------------------------
    % inspect detection
    
    % memory map to raw data
    mraw = memmapfile(fraw.name, 'Format', {'int16' [nchans nsamps] 'mapped'});
    draw = mraw.data;
    
    % params
    chunk2plot = [1 : 10 * fs];
    clr = ['kbgroym'];
    grp = 3;            % selected grp        
    
    % load raw
    raw = [draw.mapped(spkgrp{grp}, chunk2plot)]';
    
    % repeat detection for selected grp
    wh = d.mapped(spkgrp{grp}, chunk2plot);
    wh = gpuArray(wh');
    wh = single(wh);
    wh = wh / scaleproc;   
    smin = my_min(wh, loc_range, [1, 2]);
    crossings = wh < smin + 1e-5 & wh < thr;
    [samp, ch, amp] = find(crossings .* wh); 
    [samp, ia] = sort(gather(samp));
    ch = gather(ch(ia));
    amp = gather(amp(ia));
    while any(diff(samp) < dt)
        idx = find(diff(samp) <= dt);
        idx2 = amp(idx) > amp(idx + 1);
        idx3 = sort([idx(idx2); idx(~idx2) + 1]);
        amp(idx3) = [];
        samp(idx3) = [];
        ch(idx3) = [];
    end
    
    % raw
    figure
    ax1 = subplot(3, 1, 1);
    yOffset = gather(min(range(raw)));
    hold on
    for i = length(spkgrp{grp}) : -1 : 1
        plot(chunk2plot / fs, raw(:, i)...
            + yOffset * (i - 1), clr(i))
    end
    set(gca, 'TickLength', [0 0])
    title('Raw')
    
    % wh
    ax2 = subplot(3, 1, 2);
    yOffset = gather(max(range(wh)));
    hold on
    for i = length(spkgrp{grp}) : -1 : 1
        plot(chunk2plot / fs, wh(:, i)...
            + yOffset * (i - 1), clr(i))
        scatter(samp(ch == i) / fs, amp(ch == i) + yOffset * (i - 1), '*')
        yline(thr + yOffset * (i - 1), '--r');
    end
    set(gca, 'TickLength', [0 0])
    title('Whitened')
    
    % min
    ax3 = subplot(3, 1, 3);
    yOffset = gather(max(range(smin)));
    hold on
    for i = length(spkgrp{grp}) : -1 : 1
        plot(chunk2plot / fs, smin(:, i)...
            + yOffset * (i - 1), clr(i))
    end
    set(gca, 'TickLength', [0 0])
    xlabel('Time [s]')
    title('Local Minimum')
    linkaxes([ax1, ax2, ax3], 'x')
    
    % ---------------------------------------------------------------------
    % isi histogram
    figure
    binEdges = [0 : dt : 1000];      % 0 - 50 ms
    histogram(diff(samp), binEdges, 'EdgeColor', 'none', 'FaceColor', 'k')
    xlim([binEdges(1) binEdges(end)])
    xlabel('ISI [samples]')
    ylabel('Counts')
    
end
