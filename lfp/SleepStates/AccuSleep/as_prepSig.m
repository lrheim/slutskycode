function [EMG, EEG, sigInfo] = as_prepSig(eegData, emgData, varargin)

% prepare signals for accusleep. filters and subsamples eeg and emg. two
% options to input data; ALT 1 is to directly input eeg and emg data as
% vectors (e.g. via getLFP). this requires inputing the signals sampling
% frequency. ALT 2 is to load traces from an lfp / dat file. recommend
% using session info struct (cell explorer format) and inputing the signal
% channels within the file.
%
% INPUT:
%   eegData     ALT 1; eeg numeric data (1 x n1).
%               ALT 2; string. name of file with data. must include
%               extension (e.g. lfp / dat)
%   emgData     ALT 1; emg numeric data (1 x n2).
%               ALT 2; string. name of file with data. must include
%               extension (e.g. lfp / dat)
%   fs          numeric. requested new sampling frequency
%   eegFs       numeric. eeg sampling frequency
%   emgFs       numeric. emg sampling frequency
%   eegCh       numeric. channel number of eeg to load from lfp file. can
%               be a vector and then the channels will be averaged. 
%   emgCh       numeric. channel number of eeg to load from lfp file. for
%               oe recording system
%   emgCf       numeric. cut off frequency for emg signal [10 200] or acc
%               signal [10 600]. decided by RA, HB, and LH 20 apr 21
%   eegCf       numeric. low-pass frequency for eeg signal [60]
%   eegNchans   numeric. no channels in eeg data file. if empty will be
%               extracted from session info file
%   emgNchans   numeric. no channels in emg data file. if empty will equal
%               to eegNchans
%   basepath    string. path to recording folder {pwd}
%   saveVar     logical. save ss var {true}
%   forceLoad   logical. reload recordings even if mat exists
%   inspectSig  logical. inspect signals via accusleep gui {false}
%
% DEPENDENCIES:
%   rmDC
%   iosr.DSP.SINCFILTER     for low-pass filtering EEG data
%
% TO DO LIST:
%       # implement cleanSig
%       # input nchans for emg / eeg files separately
%
% 19 apr 21 LH

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic;

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'eegCh', 1, @isnumeric);
addOptional(p, 'emgCh', 1, @isnumeric);
addOptional(p, 'eegFs', [], @isnumeric);
addOptional(p, 'emgFs', [], @isnumeric);
addOptional(p, 'fs', 1250, @isnumeric);
addOptional(p, 'eegNchans', [], @isnumeric);
addOptional(p, 'emgNchans', [], @isnumeric);
addOptional(p, 'emgCf', [10 600], @isnumeric);
addOptional(p, 'eegCf', [], @isnumeric);
addOptional(p, 'saveVar', true, @islogical);
addOptional(p, 'inspectSig', false, @islogical);
addOptional(p, 'forceLoad', false, @islogical);

parse(p, varargin{:})
basepath        = p.Results.basepath;
eegCh           = p.Results.eegCh;
emgCh           = p.Results.emgCh;
eegFs           = p.Results.eegFs;
emgFs           = p.Results.emgFs;
fs              = p.Results.fs;
emgCf           = p.Results.emgCf;
eegCf           = p.Results.eegCf;
eegNchans       = p.Results.eegNchans;
emgNchans       = p.Results.emgNchans;
saveVar         = p.Results.saveVar;
inspectSig      = p.Results.inspectSig;
forceLoad       = p.Results.forceLoad;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% file names
cd(basepath)
mousepath = fileparts(basepath);
[~, basename] = fileparts(basepath);
eegfile = [basename '.AccuSleep_EEG.mat'];
emgfile = [basename '.AccuSleep_EMG.mat'];
sigInfofile = [basename '.AccuSleep_sigInfo.mat'];
sessionInfoFile = [basename, '.session.mat'];

% initialize
sigInfo = [];
recDur = [];

% reload data if already exists and return
if exist(emgfile, 'file') && exist(eegfile, 'file') && ~forceLoad
    fprintf('\n%s and %s already exist. loading...\n', emgfile, eegfile)
    load(eegfile, 'EEG')
    load(emgfile, 'EMG')
    return
end
    
% import toolbox for filtering    
import iosr.dsp.*

% session info
if exist(sessionInfoFile, 'file')
    load([basename, '.session.mat'])
    recDur = session.general.duration;
    if isempty(eegNchans)
        eegNchans = session.extracellular.nChannels;
    end
    if isempty(eegFs)
        eegFs = session.extracellular.srLfp;
    end
    if isempty(emgFs)
        emgFs = eegFs;
    end
end
if isempty(emgNchans)
    emgNchans = eegNchans;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% eeg
fprintf('\nworking on %s\n', basename)
fprintf('loading data...')
if ischar(eegData) || isempty(eegData)
    if isempty(eegData)
        eegData = [basename '.lfp'];
        if ~exist(eegData, 'file')
            eegData = [basename '.dat'];
            if ~exist(eegData, 'file')
                error('could not fine %s. please specify lfp file or input data directly', eegfile)
            end
        end
    end
        
    % load average across given channels
    eegOrig = double(bz_LoadBinary(eegData, 'duration', Inf,...
        'frequency', eegFs, 'nchannels', eegNchans, 'start', 0,...
        'channels', eegCh, 'downsample', 1));
    if size(eegOrig, 2) > 1
        eegOrig = mean(eegOrig, 2);
    end
else
    eegOrig = eegData;
end

% emg
if ischar(emgData) || isempty(emgData)
    if isempty(emgData)
        emgData = [basename '.lfp'];
        if ~exist(emgData, 'file')
            emgData = [basename '.dat'];
            if ~exist(emgData, 'file')
                error('could not fine %s. please specify lfp file or input data directly', eegfile)
            end
        end
    end
        
    emgOrig = double(bz_LoadBinary(emgData, 'duration', Inf,...
        'frequency', emgFs, 'nchannels', emgNchans, 'start', 0,...
        'channels', emgCh, 'downsample', 1));        
else
    emgOrig = emgData;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% filter and downsample
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% low-pass filter eeg to assure nyquist.
% note accusleep only uses spectrogram up to 50 Hz
if ~isempty(eegCf)
    fprintf('\nfiltering EEG, cutoff = %d Hz', eegCf)
    filtRatio = eegCf / (eegFs / 2);
    eegOrig = iosr.dsp.sincFilter(eegOrig, filtRatio);
end

if ~isempty(emgCf)   
    fprintf('\nfiltering EMG, cutoff = %d Hz', emgCf)
    filtRatio = emgCf / (emgFs / 2);
    emgOrig = iosr.dsp.sincFilter(emgOrig, filtRatio);    
end

% remove DC component from eeg
fprintf('\nremoving DC component\n')
eegOrig = rmDC(eegOrig, 'dim', 1);

if isempty(recDur)
    recDur = length(eegOrig) / eegFs;
end

% validate recording duration and sampling frequency. subsample emg and eeg
% to the same length. assumes both signals span the same time interval.
% interpolation, as opposed to idx subsampling, is necassary for cases
% where the sampling frequency is not a round number (tdt).
if length(emgOrig) ~= length(eegOrig) || fs ~= emgFs
    emgDur = length(emgOrig) / emgFs;
    eegDur = length(eegOrig) / eegFs;
    if abs(emgDur - eegDur) > 2
        warning(['EEG and EMG are of differnet duration (diff = %.2f s).\n',...
            'Check data and sampling frequencies.\n'], abs(emgDur - eegDur))
    end
    tstamps_sig = [1 / fs : 1 / fs : recDur];
    
    
    fprintf('downsampling to %d Hz\n', fs)
    EMG = [interp1([1 : length(emgOrig)] / emgFs, emgOrig, tstamps_sig,...
        'spline')]';
    EEG = [interp1([1 : length(eegOrig)] / eegFs, eegOrig, tstamps_sig,...
        'spline')]';
else
    EMG = emgOrig;
    EEG = eegOrig;
end

EMG = EMG(:);
EEG = EEG(:);

% remove 50 from emg
% [EMG, tsaSig, ~] = tsa_filter('sig', EMG, 'fs', fs, 'tw', false,...
%     'ma', true, 'graphics', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% finilize and save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sigInfo.newFs = fs;
sigInfo.eegFs = eegFs;
sigInfo.emgFs = emgFs;
sigInfo.eegCf = eegCf;
sigInfo.emgCf = emgCf;
sigInfo.emgCh = emgCh;
sigInfo.eegCh = eegCh;
if ischar(emgData)
    sigInfo.emgFile = emgData;
else
    sigInfo.emgFile = 'inputData';
end
if ischar(eegData)
    sigInfo.eegFile = eegData;
else
    sigInfo.eegFile = 'inputData';
end

% save files
if saveVar
    fprintf('saving signals... ')
    save(eegfile, 'EEG')
    save(emgfile, 'EMG')
    save(sigInfofile, 'sigInfo')
    fprintf('done.\nthat took %.2f s\n\n', toc)
end

% inspect signals
if inspectSig
    AccuSleep_viewer(EEG, EMG, fs, 1, [], [])
end

return

% EOF

% -------------------------------------------------------------------------
% interpolate labels to a different fs
oldFs = 1000;
newFs = 1250;

% subsample
labelsNew = labels(1 : newFs / oldFs : end)

% interpolate
labelsNew = interp1([1 : floor(length(EEG) / oldFs)], labels, [1 : floor(length(EEG) / newFs)]);
labelsNew = round(labelsNew);       % necassary only if upsampling
labels = labelsNew;

% -------------------------------------------------------------------------
% call for lfp and emg in same file 
[EMG, EEG, sigInfo] = as_prepSig([basename, '.lfp'], [],...
    'eegCh', [1 : 4], 'emgCh', 33, 'saveVar', true, 'emgNchans', [], 'eegNchans', nchans,...
    'inspectSig', false, 'forceLoad', true, 'eegFs', 1250, 'emgFs', [],...
    'emgCf', [10 600], 'eegCf', [], 'fs', 1250);


% call for emg dat file
[EMG, EEG, sigInfo] = as_prepSig([basename, '.lfp'], [basename, '.emg.dat'],...
    'eegCh', [8 : 11], 'emgCh', 1, 'saveVar', true, 'emgNchans', 2, 'eegNchans', nchans,...
    'inspectSig', false, 'forceLoad', true, 'eegFs', 1250, 'emgFs', 3051.7578125,...
    'emgCf', [10 600]);

% call for accelerometer
[EMG, EEG, sigInfo] = as_prepSig([basename, '.lfp'], acc.mag,...
    'eegCh', [1 : 4], 'emgCh', [], 'saveVar', true, 'emgNchans', [],...
    'eegNchans', nchans, 'inspectSig', false, 'forceLoad', true,...
    'eegFs', 1250, 'emgFs', 1250, 'eegCf', [], 'emgCf', [10 600], 'fs', 1250);

% -------------------------------------------------------------------------
% fix special case where emg changes in the middle of a recording, such as
% the sudden appearance of strong HR artifacts. Thus, although wake and
% nrem are still noticeable different, the difference between them is not
% homegenous and the same calibration matrix cannot be used for the entire
% recording. so, classify the recording twice (or more) and each time
% during the calibration use only the manual (calibration) labels from the
% parts of the recording that look similar. then, combine the labels from
% the different classifications. The transitions will probably need to be
% manually labeled. 