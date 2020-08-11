function LFPfromDat(varargin)

% performs lowpass filter on wideband data (basename.dat file), subsamples
% the filtered data and saves as a new flat binary. filtering is performed
% by FFT-based convolution with the sinc kernel (IOSR.DSP.SINCFILTER).
% based on bz_LFPdromDat with the following differences: (1) no
% dependencies on sessionInfo, (2) bz handles the remainder separately s.t.
% there is a continuity problem at the last chunk, (3) feeds sincFilter all
% channels at once (not much difference because sincFilter loops through
% channels anyway), (4) slightly faster (180 vs 230 s for 90 m recording),
% (5) no annoying waitbar.
%  
% because the way downsampling occurs, the final duration may not be
% accurate if the input fs is not a round number. one way arround
% this is to define the output fs s.t. the ratio output/input is round.
% however, this is not possible for many inputs (including 24414.06). do
% not see a way around this inaccuracy (~50 ms for 90 m recording). 
% 
% despite the description in IOSR.DSP.SINCFILTER, the output is slightly
% different if the cutoff frequency is [0 450] instead of [450].
% 
% INPUT
%   basename    string. filename of lfp file. if empty retrieved from
%               basepath. if .lfp should not include extension, if .wcp
%               should include extension
%   basepath    string. path to load filename and save output {pwd}
%   precision   char. sample precision of dat file {'int16'} 
%   clip        mat n x 2 indicating samples to diregard from chunks.
%               for example: clip = [0 50; 700 Inf] will remove the first
%               50 samples and all samples between 700 and n
%   fsIn        numeric [Hz]. sampling frequency of dat file {20000}
%   fsOut       numeric [Hz]. sampling frequency of lfp file {1250}
%   nchans      numeric. number of channels in dat file {16}
%   cf          numeric. cutoff frequencies {[0 450]}.
%   saveVar     save variable {1}.
%   
% DEPENDENCIES
%   IOSR.DSP.SINCFILTER
%   class2bytes
% 
% OUTPUT
%   lfp         structure with the following fields:
%   fs
%   fs_orig
%   extension
%   interval    
%   duration    
%   chans
%   timestamps 
%   data  
% 
% % 11 aug 20 LH
%
% TO DO LIST
%       


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'basename', '');
addOptional(p, 'extension', 'lfp');
addOptional(p, 'forceL', false, @islogical);
addOptional(p, 'fs', 1250, @isnumeric);
addOptional(p, 'interval', [0 inf], @isnumeric);
addOptional(p, 'ch', [1 : 16], @isnumeric);
addOptional(p, 'pli', false, @islogical);
addOptional(p, 'dc', false, @islogical);
addOptional(p, 'invertSig', false, @islogical);
addOptional(p, 'saveVar', true, @islogical);
addOptional(p, 'chavg', {}, @iscell);

parse(p,varargin{:})
basepath = p.Results.basepath;
basename = p.Results.basename;
extension = p.Results.extension;
forceL = p.Results.forceL;
fs = p.Results.fs;
interval = p.Results.interval;
ch = p.Results.ch;
pli = p.Results.pli;
dc = p.Results.dc;
invertSig = p.Results.invertSig;
saveVar = p.Results.saveVar;
chavg = p.Results.chavg;

fsOut = 1250;
fsIn = 24414.06;
cf = [0 450];
nchans = 16; 
clip = [];
precision = 'int16';

chunksize = 1e5; % 

tic

[~, basename] = fileparts(basepath);
% size of one data point in bytes
nbytes = class2bytes(precision);

filtRatio = cf(2) / (fsIn / 2);
%   Y = IOSR.DSP.SINCFILTER(X,WN) applies a near-ideal low-pass or
%   band-pass brickwall filter to the array X, operating along the first
%   non-singleton dimension (e.g. down the columns of a matrix). The
%   cutoff frequency/frequencies are specified in WN. If WN is a scalar,
%   then WN specifies the low-pass cutoff frequency. If WN is a two-element
%   vector, then WN specifies the band-pass interval. WN must be 0.0 < WN <
%   1.0, with 1.0 corresponding to half the sample rate.
% 
%   The filtering is performed by FFT-based convolution of X with the sinc
%   kernel.

fsRatio = (fsIn / fsOut);
if cf(2) > fsOut / 2
    warning('low pass cutoff beyond nyquist')
end

import iosr.dsp.*

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% handle files and chunks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% handle files
fdat = fullfile(basepath,[basename,'.dat']);
flfp = fullfile(basepath,[basename,'.lfp']);

% check that basename.dat exists
if ~exist(fdat, 'file')
    error('%s does not exist', fdat)
end
datinfo = dir(fdat);

% check if basename.lfp exists
if exist(flfp, 'file') && ~force
  fprintf('%s exists, returning...', flfp)
end

% Set chunk and buffer size as even multiple of fsRatio
if mod(chunksize, fsRatio) ~= 0
    chunksize = round(chunksize + fsRatio - mod(chunksize, fsRatio));
end

ntbuff = 525;  % default filter size in iosr toolbox
if mod(ntbuff, fsRatio)~=0
    ntbuff = round(ntbuff + fsRatio - mod(ntbuff, fsRatio));
end

% partition into chunks
nsamps = datinfo.bytes / nbytes / nchans;
chunks = n2chunks('n', nsamps, 'chunksize', chunksize, 'clip', clip,...
    'overlap', ntbuff);
nchunks = size(chunks, 1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% processing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% memory map to original file
m = memmapfile(fdat, 'Format', {precision [nchans nsamps] 'mapped'});
raw = m.data;

fid = fopen(fdat, 'r');
fidOut = fopen(flfp, 'a');
for i = 1 : nchunks
    
    % print progress
    if i ~= 1
        fprintf(repmat('\b', 1, length(txt)))
    end
    txt = sprintf('working on chunk %d / %d', i, nchunks);
    fprintf(txt)
    
    % load chunk
    d = raw.mapped(:, chunks(i, 1) : chunks(i, 2));
    d = double(d);
    
    % filter
    filtered = [iosr.dsp.sincFilter(d', filtRatio)]';
    
    % downsample
    if i == 1
        dd = int16(real(filtered(:, fsRatio : fsRatio :...
            length(filtered) - ntbuff)));
    else
        dd = int16(real(filtered(:, ntbuff + fsRatio : fsRatio :...
            length(filtered) - ntbuff)));
    end

    fwrite(fidOut, dd(:), 'int16'); 
end

fclose(fid);
fclose(fidOut);

toc
fprintf('that took %.2f minutes\n', toc / 60)

disp(['lfp file created: ', flfp,'. Process time: ' num2str(toc(timerVal)/60,2),' minutes'])

  
end






% EOF