function fepsp = getfEPSPfromOE(varargin)

% this is a wrapper to get fEPSP signals from OE. Assumes preprocOE has
% been called beforehand and that basepath contains both the raw .dat file
% and din.mat
%  
% INPUT
%   basepath    string. path to .dat file (not including dat file itself)
%   fname       string. name of dat file. if empty and more than one dat in
%               path, will be extracted from basepath
%   nchans      numeric. original number of channels in dat file {35}.
%   ch          vec. channels to load from dat file {[]}. if empty than all will
%               be loaded
%   win         vec of 2 elements. determines length of snip. for example,
%               win = [5 405] than each snip will be 401 samples, starting
%               5 samples after the corresponding stamp and ending 405
%               samples after stamp. if win = [-16 16] than snip will be of
%               33 samples symmetrically centered around stamp.
%   precision   char. sample precision of dat file {'int16'}
%   fs          numeric. requested sampling frequency {1250} for
%               resampling. if empty no resampling will occur.
%   force       logical. force reload {false}.
%   concat      logical. concatenate different files (true) or not {false}. 
%               used for e.g stability.
%   saveVar     logical. save variable {1}. 
%   
% OUTPUT
%   fepsp       struct
% 
% TO DO LIST
%   # code more efficient way to convert tstamps to idx
% 
% 22 apr 20 LH          


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'fname', '', @ischar);
addOptional(p, 'nchans', 35, @isnumeric);
addOptional(p, 'ch', [], @isnumeric);
addOptional(p, 'win', [1 2000], @isnumeric);
addOptional(p, 'precision', 'int16', @ischar);
addOptional(p, 'fs', 1250, @isnumeric);
addOptional(p, 'force', false, @islogical);
addOptional(p, 'concat', false, @islogical);
addOptional(p, 'saveVar', true, @islogical);

parse(p, varargin{:})
basepath = p.Results.basepath;
fname = p.Results.fname;
nchans = p.Results.nchans;
ch = p.Results.ch;
win = p.Results.win;
precision = p.Results.precision;
fs = p.Results.fs;
force = p.Results.force;
concat = p.Results.concat;
saveVar = p.Results.saveVar;


% params
basepath = 'E:\Data\Dat\lh50\lh50_220411\090450_e1r1-9';
nchans = 31;
ch = [];
win = [1 2000];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% handle data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% make sure dat and stim files exist
datfiles = dir([basepath filesep '**' filesep '*dat']);
if isempty(datfiles)
    error('no .dat files found in %s', basepath)
end
if isempty(fname)
    if length(datfiles) == 1
        fname= datfiles.name;
    else
        fname= [bz_BasenameFromBasepath(basepath) '.dat'];
        if ~contains({datfiles.name}, fname)
            error('please specify which dat file to process')
        end
    end
end
[~, basename, ~] = fileparts(fname);

% load digital input
stimname = fullfile(basepath, [basename, '.din.mat']);
if exist(stimname) 
    fprintf('\n loading %s \n', stimname)
    load(stimname)
else
    error('%s not found', stimname)
end

% load dat info
infoname = fullfile(basepath, [basename, '.datInfo.mat']);
if exist(infoname, 'file')
    fprintf('\n loading %s \n', infoname)
    load(infoname)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% snip data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% convert tstamps to idx of samples 
for i = 1 : length(din.data)
    stamps(i) = find(datInfo.tstamps == din.data(i));
end

% snip
snips = snipFromDat('basepath', basepath, 'fname', fname,...
    'stamps', stamps, 'win', win, 'nchans', nchans, 'ch', ch,...
    'dtrend', false, 'saveVar', false, 'precision', precision);

nfiles = length(datInfo.origFile);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% find indices according to intesities (different files)
csamps = [0 cumsum(datInfo.nsamps)];
maxstim = 1;
stimidx = cell(nfiles, 1);
for i = 1 : nfiles
    stimidx{i} = find(stamps > csamps(i) &...
        stamps <  csamps(i + 1));
    maxstim = max([maxstim, length(stimidx{i})]);
end

% rearrange snips and extract amplitude
for i = 1 : nfiles
    wv{i} = snips(:, stimidx{i}, :);
    wvavg(i, :, :) = squeeze(mean(wv{i}, 2));
    ampcell{i} = abs(min(wv{i}, [], 3) - max(wv{i}, [], 3));
    stimcell{i} = stamps(stimidx{i});
end

% if concat
%     amp = [];
%     for i = 1 : length(blocks)
%         amp = [amp; ampcell{i}];
%     end
% else
%     mat = cellfun(@(x)[x(:); NaN(maxstim - length(x), 1)], ampcell,...
%         'UniformOutput', false);
%     amp = cell2mat(mat);
%     mat = cellfun(@(x)[x(:); NaN(maxstim - length(x), 1)], stimcell,...
%         'UniformOutput', false);
%     stimidx = cell2mat(mat);
% end

% arrange struct
fepsp.wv = wv;
fepsp.wvavg = wvavg;
fepsp.stim = stimidx;
% fepsp.t = 0 : 1 / fs : fdur;
% fepsp.amp = amp;
% fepsp.fs = fs;
% fepsp.fs_orig = info.fs;
fepsp.ch = ch;

% save variable
savename = fullfile(basepath, [basename, '.fepsp.mat']);

if saveVar   
    save(savename, 'fepsp')
end

end