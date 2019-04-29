function emg = getEMG(basepath, store, blocks, rmvch)

% loads EMG from tank (TDT) and finds linear envelope. 
%
% INPUT:
%   basepath    path to recording folder {pwd}.
%   store       stream. typically {'Raw1'} or 'Raw2'
%   blocks      vector. blocks to convert {all}. e.g. [1 2 4 5];
%   chunksize   load data in chunks {60} s. if empty will load entire block.
%   mapch       new order of channels {[]}.
%   rmvch       channels to remove (according to original order) {[]}
%   clip        array of mats indicating times to diregard from recording.
%               each cell corresponds to a block. for example:
%               clip{3} = [0 50; 700 Inf] will remove the first 50 s of
%               Block-3 and the time between 700 s and the end of Block-3
%
% OUTPUT
%   emg        struct with fields describing tdt params
% 
% CALLS:
%   TDTbin2mat
%
% TO DO LIST:
%   handle arguments
%
% 29 apr 19 LH

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || isempty(basepath)
    basepath = pwd;
end
if nargin < 2 || isempty(store)
    store = 'EMG1';
end
if nargin < 3 || isempty(blocks)
    blocks = [];
end
if nargin < 4 || isempty(rmvch)
    rmvch = [];
end

[~, basename] = fileparts(basepath);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get tank blocks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cd(basepath)
blockfiles = dir('block*');
blocknames = {blockfiles.name};
fprintf(1, '\nFound %d blocks in %s\n\n', length(blocknames), basepath);

if isempty(blocknames)
    error('no blocks in dir %s.', basepath)
end
if ~isempty(blocks)
    blocknames = blocknames(blocks);
end
nblocks = length(blocknames);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load EMG
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

data = [];
for i = 1 : nblocks
    blockpath = fullfile(basepath, blocknames{i});
    fprintf(1, 'Working on %s\n', blocknames{i});
    
    heads = TDTbin2mat(blockpath, 'TYPE', {'streams'}, 'STORE', store, 'HEADERS', 1);
    nsec(i) = heads.stores.(store).ts(end);
    fs = heads.stores.(store).fs;
    
    raw = TDTbin2mat(blockpath, 'TYPE', {'streams'}, 'STORE', store,...
        'T1', 0, 'T2', 0);
    raw = raw.streams.(store).data;
end

if ~isempty(rmvch)
    raw(rmvch, :) = [];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% find linear envelope
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% OPTION 1:
% [EMG, ~] = envelope(double(EMG2), win, 'rms');

% OPTION 2:
% bandpass filter
data = filterLFP(double(raw'), 'fs', fs,...
    'type', 'butter', 'passband', [10 500], 'graphics', false);

% rectify
data = abs(data - mean(data));

% low-pass filter
win = round(0.5 * fs);    % 500 ms moving average
data = movmean(data, win);

% normalize
data = data / max(data);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save var
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
emg.data = data;
emg.raw = raw;
emg.filename = basename;
emg.blocks = blocks;
emg.blockduration = nsec;
emg.rmvch = rmvch;
emg.fs = heads.stores.(store).fs;

save([basename, '.emg.mat'], 'emg');

end

% EOF