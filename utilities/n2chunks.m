function [chunks] = n2chunks(varargin)

% gets a number of elements and divides it to chunks of chunksize. handles
% start/end points. allows clipping of certain elements and overlap between
% chunks. update dec 21: fixed problem that occured when two or more clips
% were in the same chunk. 
%
% INPUT:
%   n           numeric. number of elements to split
%   chunksize   numeric. number of elements in a chunk {1e6}. 
%   overlap     2-element vector defining the overlap between chunks. 
%               first element is reduced from chunk start and second
%               element is added to chunk end. if single value is specified
%               than the overlap will be symmetrical start to end. for
%               example, overlap = [100 150] for chunksize = 1000
%               chunks may be [1 1150; 900 2150]. 
%   clip        mat n x 2 indicating samples to diregard from chunks.
%               for example: clip = [0 50; 700 Inf] will remove the first
%               50 samples and all samples between 700 and n
%
% OUTPUT
%   chunks      mat n x 2 
%
% CALLS:
%
% TO DO LIST:
%   # add an option to restrict minimum chunk size
%
% 22 apr 20 LH  updates:
% 11 aug 20 LH  overlap
% 14 dec 21 LH  fixed clipping


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

p = inputParser;
addOptional(p, 'n', [], @isnumeric);
addOptional(p, 'chunksize', [], @isnumeric);
addOptional(p, 'overlap', [0 0], @isnumeric);
addOptional(p, 'clip', [], @isnumeric);

parse(p, varargin{:})
n = p.Results.n;
chunksize = p.Results.chunksize;
overlap = p.Results.overlap;
clip = p.Results.clip;

if numel(overlap) == 1
    overlap = [overlap overlap];
elseif numel(overlap) > 2
    error('overlap must be a 2-element vector')
end
if isempty(overlap)
    overlap = [0 0];
end

% validate
% if max(clip(:)) > n
%     error('')
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% partition into chunks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% partition into chunks
if isempty(chunksize)       % load entire file
    chunks = [1 n];
else                        % load file in chunks
    nchunks = ceil(n / chunksize);
    chunks = [1 : chunksize : chunksize * nchunks;...
        chunksize : chunksize : chunksize * nchunks]';
    chunks(nchunks, 2) = n;
end

% insert overlap
chunks(:, 1) = chunks(:, 1) - overlap(1);
chunks(:, 2) = chunks(:, 2) + overlap(2);
chunks(nchunks, 2) = n;
chunks(1, 1) = 1;

% assimilate clip into chunks
for iclip = 1 : size(clip, 1)
    
    % change chunk end to clip start
    clip_start = find(clip(iclip, 1) < chunks(:, 2), 1, 'first');
    chunk_end = chunks(clip_start, 2);
    chunks(clip_start, 2) = clip(iclip, 1) - 1;
    
    if iclip == size(clip, 1)
        % change chunk start to clip end
        chunks(clip_start + 1, 1) = clip(iclip, 2) - 1;
    else
        % add another chunk from clip end to clip + 1 start
        chunks = [chunks(1 : clip_start, :);...
            clip(iclip, 2) + 1, chunk_end;...           
            chunks(clip_start + 1 : end, :)];
    end
    
    % remove chunks that are after clip. this occurs when clip is greater
    % than chunksize.
    rmidx = find(chunks(:, 1) > chunks(:, 2));
    chunks(rmidx + 1, 1) = chunks(rmidx, 1);
    chunks(rmidx, :) = [];
end

% remove chunks that are greater than nsamps. this can occur if clip
% includes Inf
chunks(find(chunks > n) : end, :) = [];

end