function lfp = getLFP(varargin)

% gets lfp from lfp file for each channel. can specify channels and
% intervals, average across channels, and resample. if field recordings
% than inverted.
%  
% INPUT
%   basename    string. filename of lfp file. if empty retrieved from
%               basepath. should not include extension
%   basepath    string. path to load filename and save output {pwd}
%   extension   load from {'lfp'} (neurosuite), 'abf', or 'wcp'.
%   forceL      logical. force reload {false}.
%   fs          numeric. requested sampling frequency {1250}
%   interval    numeric mat. list of intervals to read from lfp file [s]
%   ch          vec. channels to load
%   pli         logical. filter power line interferance (1) or not {0}
%   saveVar     save variable {1}.
%   chavg       cell. each row contain the lfp channels you want to average
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
% 01 apr 19 LH & RA
% 19 nov 19 LH          load mat if exists  
% 14 jan 19 LH          adapted for wcp and abf and resampling

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
saveVar = p.Results.saveVar;
chavg = p.Results.chavg;

nchans = length(ch);

if isempty(interval)
    interval = [0 inf];
end
if isempty(basename)
    [~, basename] = fileparts(basepath);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% check if file exists
cd(basepath)
filename = [basename '.lfp.mat'];
if exist(filename) && ~forceL
    fprintf('\n loading %s \n', filename)
    load(filename)
    return
end

loadname = [basename '.' extension];
switch extension
    case 'lfp'
        fs_orig = 1250;
        lfp.data = bz_LoadBinary(loadname, 'duration', diff(interval),...
            'frequency', fs_orig, 'nchannels', nchans, 'start', interval(1),...
            'channels', ch, 'downsample', 1);
    case 'abf'
        % note abf2load cannot handles spaces in loadname
        % note abf2load requires Abf2Tmp.exe and ABFFIO.dll in basepath         
        [lfp.data, info] = abf2load(loadname);
        fs_orig = 1 / (info.fADCSequenceInterval / 1000000); 
    case 'wcp'
        data = import_wcp();
        lfp.data = data.S;
        fs_orig = data.fs;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% messaround
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% do not resample if new sampling frequency not specified 
if isempty(fs)
    fs = fs_orig;
end
% resmaple
if fs ~= fs_orig
    lfp.data = resample(double(lfp.data), fs, round(fs_orig));
    fprintf('\n resampling from %.1f to %.1f\n\n', fs_orig, fs)
end
% invert
if ~strcmp(extension, 'lfp') && abs(min(lfp.data)) > max(lfp.data)
    lfp.data = -lfp.data;
    fprintf('\n inverting data \n\n')
end
% filter
if pli
    linet = lineDetect('x', lfp.data, 'fs', fs, 'graphics', false);
    lfp.data = lineRemove(lfp.data, linet, [], [], 0, 1);
end
% flip such that samples x channels
if size(lfp.data, 1) < size(lfp.data, 2)
    lfp.data = lfp.data';
end
% signal average
if ~isempty(chavg)
    mlfp = zeros(size(chavg, 1), length(lfp.data));
    for i = 1 : size(chavg, 1)
        mlfp(i, :) = mean(lfp.data(:, chavg{i}), 2);
    end    
    lfp.data = mlfp;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arrange and save struct
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

lfp.timestamps = (interval(1) : 1 / fs : interval(1) + (length(lfp.data) - 1) / fs)';

if interval(2) == inf
    inteval(2) = lfp.timestamps(end);
end
lfp.interval = interval;
lfp.duration = length(lfp.data) / fs;
lfp.chans = ch;
lfp.fs = fs;
lfp.fs_orig = fs_orig;
lfp.extension = extension;

% save variable
if saveVar   
    save([basepath, filesep, filename], 'lfp')
end



end
