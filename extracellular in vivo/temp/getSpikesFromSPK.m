function spikes = getSpikes(varargin)
% bz_getSpikes - Get spike timestamps.
%
% USAGE
%
%    spikes = bz_getSpikes(varargin)
% 
% INPUTS
%
%    spikeGroups     -vector subset of shank IDs to load (Default: all)
%    region          -string region ID to load neurons from specific region
%                     (requires sessionInfo file or units->structures in xml)
%    UID             -vector subset of UID's to load 
%    basepath        -path to recording (where .dat/.clu/etc files are)
%    getWaveforms    -logical (default=true) to load mean of raw waveform data
%    forceL          -logical (default=false) to force loading from
%                     res/clu/spk files
%    saveMat         -logical (default=false) to save in buzcode format
%    noPrompts       -logical (default=false) to supress any user prompts
%    
% OUTPUTS
%
%    spikes - cellinfo struct with the following fields
%          .sessionName    -name of recording file
%          .UID            -unique identifier for each neuron in a recording
%          .times          -cell array of timestamps (seconds) for each neuron
%          .spindices      -sorted vector of [spiketime UID], useful for 
%                           input to some functions and plotting rasters
%          .region         -region ID for each neuron (especially important large scale, high density probes)
%          .shankID        -shank ID that each neuron was recorded on
%          .maxWaveformCh  -channel # with largest amplitude spike for each neuron
%          .rawWaveform    -average waveform on maxWaveformCh (from raw .dat)
%          .cluID          -cluster ID, NOT UNIQUE ACROSS SHANKS
%           
% NOTES
%
% This function can be used in several ways to load spiking data.
% Specifically, it loads spiketimes for individual neurons and other
% sessionInfodata that describes each neuron.  Spiketimes can be loaded using the
% UID(1-N), the shank the neuron was on, or the region it was recorded in.
% The default behavior is to load all spikes in a recording. The .shankID
% and .cluID fields can be used to reconstruct the 'units' variable often
% used in FMAToolbox.
% units = [spikes.shankID spikes.cluID];
% 
% 
% first usage recommendation:
% 
%   spikes = bz_getSpikes('saveMat',true); Loads and saves all spiking data
%                                          into buzcode format .cellinfo. struct
% other examples:
%
%   spikes = bz_getSpikes('spikeGroups',1:5); first five shanks
%
%   spikes = bz_getSpikes('region','CA1'); cells tagged as recorded in CA1
%
%   spikes = bz_getSpikes('UID',[1:20]); first twenty neurons
%
%
% written by David Tingley, 2017
% 
% 23 nov 18 LH - added avg and std waveform fields
% 07 feb 20 LH - fixed orientation given one electrode

%% Deal With Inputs 
spikeGroupsValidation = @(x) assert(isnumeric(x) || strcmp(x,'all'),...
    'spikeGroups must be numeric or "all"');

p = inputParser;
addParameter(p,'spikeGroups','all',spikeGroupsValidation);
addParameter(p,'region','',@isstr); % won't work without sessionInfodata 
addParameter(p,'UID',[],@isvector);
addParameter(p,'basepath',pwd,@isstr);
addParameter(p,'getWaveforms',true,@islogical)
addParameter(p,'forceL',false,@islogical);
addParameter(p,'saveMat',false,@islogical);
addParameter(p,'noPrompts',false,@islogical);

parse(p,varargin{:})

spikeGroups = p.Results.spikeGroups;
region = p.Results.region;
UID = p.Results.UID;
basepath = p.Results.basepath;
getWaveforms = p.Results.getWaveforms;
forceL = p.Results.forceL;
saveMat = p.Results.saveMat;
noPrompts = p.Results.noPrompts;

% [~, filename] = fileparts(basepath);
% filename = [basepath, '\', filename, '.xml'];
cd(basepath)

forceL = false;

session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'force', false, 'saveVar', false);
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;
        
% load spikes if exist
[~, filename] = fileparts(basepath);
spkname = [filename '.spikes.cellinfo.mat'];
if exist(spkname, 'file') 
    sprintf('\nloading %s\n', spkname)
    load(spkname)
else
    sprintf('\nextracting spike waveforms\n')
end

% check that fields exist
if exist('spikes', 'var')
    if all(isfield(spikes, {'avgwv', 'stdwv'})) && force == false
        sprintf('all fields exist, skipping...')
        return
    end
end
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% handle files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% find res / clu / fet / spk files here
clufiles = dir([basepath filesep '*.clu*']);  
resfiles = dir([basepath filesep '*.res*']);
spkfiles = dir([basepath filesep '*.spk*']);

% remove *temp*, *autosave*, and *.clu.str files/directories
tempFiles = zeros(length(clufiles), 1);
for i = 1 : length(clufiles) 
    % Check whether the component after the last dot is a number or not. If
    % not, exclude the file/dir.
    dummy = strsplit(clufiles(i).name, '.'); 
    if ~isempty(findstr('temp', clufiles(i).name)) |...
            ~isempty(findstr('autosave', clufiles(i).name)) |...
            isempty(str2num(dummy{length(dummy)})) |...
        find(contains(dummy, 'clu')) ~= length(dummy)-1  
        tempFiles(i) = 1;
    end
end
clufiles(tempFiles == 1) = [];

tempFiles = zeros(length(resfiles), 1);
for i = 1:length(resfiles)
    if ~isempty(findstr('temp', resfiles(i).name)) |...
            ~isempty(findstr('autosave', resfiles(i).name))
        tempFiles(i) = 1;
    end
end
resfiles(tempFiles == 1) = [];
tempFiles = zeros(length(spkfiles), 1);
for i = 1:length(spkfiles)
    if ~isempty(findstr('temp', spkfiles(i).name)) |...
            ~isempty(findstr('autosave', spkfiles(i).name))
        tempFiles(i) = 1;
    end
end
spkfiles(tempFiles == 1) = [];

if isempty(clufiles) || isempty(resfiles) || isempty(spkfiles)
    error('no files found...')
end

if length(resfiles) ~= length(clufiles) ||...
        length(clufiles) ~= length(spkfiles) ||...
        length(spkfiles) ~= length(fetfiles)
    warning('different number of res / clu / spk / fet files')
end

% use the .clu files to get spike ID's and generate UID and spikeGroup
% use the .res files to get spike times
count = 1;

for i=1:length(clufiles) 
    disp(['working on ' clufiles(i).name])
    
    temp = strsplit(clufiles(i).name,'.');
    shankID = str2num(temp{length(temp)}); %shankID is the spikegroup number
    clu = load(fullfile(basepath,clufiles(i).name));
    clu = clu(2:end); % toss the first sample to match res/spk files
    res = load(fullfile(basepath,resfiles(i).name));
    nSamples = sessionInfo.spikeGroups.nSamples(shankID);
    spkGrpChans = sessionInfo.spikeGroups.groups{shankID}; % we'll eventually want to replace these two lines
    
    if getWaveforms && sum(clu)>0 %bug fix if no clusters 
        % load waveforms
        chansPerSpikeGrp = length(sessionInfo.spikeGroups.groups{shankID});
        fid = fopen(fullfile(basepath,spkfiles(i).name),'r');
        wav = fread(fid,[1 inf],'int16=>int16');
        try %bug in some spk files... wrong number of samples?
            wav = reshape(wav,chansPerSpikeGrp,nSamples,[]);
        catch
            error(['something is wrong with your .spk file, no waveforms.',...
                ' Use ''getWaveforms'', false while you get that figured out.'])
        end
        wav = permute(wav,[3 1 2]);
    end
    
    cells  = unique(clu);
    % remove MUA and NOISE clusters...
    cells(cells==0) = [];
    cells(cells==1) = [];  % consider adding MUA as another input argument...?
    
    for c = 1:length(cells)
       spikes.UID(count) = count; % this only works if all shanks are loaded... how do we optimize this?
       ind = find(clu == cells(c));
       spikes.times{count} = res(ind) ./ spikes.samplingRate;
       spikes.shankID(count) = shankID;
       spikes.cluID(count) = cells(c);

       %Waveforms    
       if getWaveforms
           wvforms = squeeze(mean(wav(ind,:,:)))-mean(mean(mean(wav(ind,:,:)))); % mean subtract to account for slower (theta) trends
           
            % 24 nov 18 LH      added avg and std
            % 07 feb 20 LH      reshape for cases with one electrode        
            wvvar = squeeze(std(double((wav(ind, :, :)))));
            spikes.avgWaveform{count} = reshape(wvforms, sort(size(wvforms)));
            spikes.stdWaveform{count} = reshape(wvvar, sort(size(wvvar)));
           
           if prod(size(wvforms))==length(wvforms)%in single-channel groups wvforms will squeeze too much and will have amplitude on D1 rather than D2
               wvforms = wvforms';%fix here
           end
           for t = 1:size(wvforms,1)
              [a(t) b(t)] = max(abs(wvforms(t,:))); 
           end
           [aa bb] = max(a,[],2);
           spikes.rawWaveform{count} = wvforms(bb,:);
           spikes.maxWaveformCh(count) = spkGrpChans(bb);  
           %Regions (needs waveform peak)
           if isfield(sessionInfo,'region') %if there is regions field in your metadata
                spikes.region{count} = sessionInfo.region{find(spkGrpChans(bb)==sessionInfo.channels)};
           elseif isfield(sessionInfo,'Units') %if no regions, but unit region from xml via Loadparamteres
                %Find the xml Unit that matches group/cluster
                unitnum = cellfun(@(X,Y) X==spikes.shankID(count) && Y==spikes.cluID(count),...
                    {sessionInfo.Units(:).spikegroup},{sessionInfo.Units(:).cluster});
                if sum(unitnum) == 0
                    display(['xml Missing Unit - spikegroup: ',...
                        num2str(spikes.shankID(count)),' cluster: ',...
                        num2str(spikes.cluID(count))])
                    spikes.region{count} = 'missingxml';
                else %possible future bug: two xml units with same group/clu...              
                    spikes.region{count} = sessionInfo.Units(unitnum).structure;
                end
           end
           clear a aa b bb
       end
       
       count = count + 1;
    end
end

spikes.sessionName = sessionInfo.FileName;

end

%% save to buzcode format (before exclusions)
if saveMat
    save([basepath filesep sessionInfo.FileName '.spikes.mat'],'spikes')
end


%% filter by spikeGroups input
if ~strcmp(spikeGroups,'all')
    [toRemove] = ~ismember(spikes.shankID,spikeGroups);
    spikes.UID(toRemove) = [];
    for r = 1:length(toRemove)
        if toRemove(r) == 1
         spikes.times{r} = [];
         spikes.region{r} = [];
        end
    end
    spikes.times = removeEmptyCells(spikes.times);
    spikes.region = removeEmptyCells(spikes.region);
    spikes.cluID(toRemove) = [];
    spikes.shankID(toRemove) = [];
    
    if getWaveforms
    for r = 1:length(toRemove)
        if toRemove(r) == 1
         spikes.rawWaveform{r} = [];
        end
    end
    spikes.rawWaveform = removeEmptyCells(spikes.rawWaveform);
    spikes.maxWaveformCh(toRemove) = [];
    end
end
%% filter by region input
if ~isempty(region)
    if ~isfield(spikes,'region') %if no region information in metadata
        error(['You selected to load cells from region "',region,...
            '", but there is no region information in your sessionInfo'])
    end
    
  toRemove = ~ismember(spikes.region,region);
    if sum(toRemove)==length(spikes.UID) %if no cells from selected region
        warning(['You selected to load cells from region "',region,...
            '", but none of your cells are from that region'])
    end
  
    spikes.UID(toRemove) = [];
    for r = 1:length(toRemove)
        if toRemove(r) == 1
         spikes.times{r} = [];
         spikes.region{r} = [];
        end
    end
    spikes.times = removeEmptyCells(spikes.times);
    spikes.region = removeEmptyCells(spikes.region);
    spikes.cluID(toRemove) = [];
    spikes.shankID(toRemove) = [];
    
    if getWaveforms
    if isfield(spikes,'rawWaveform')
        for r = 1:length(toRemove)
            if toRemove(r) == 1
             spikes.rawWaveform{r} = [];
            end
        end
        spikes.rawWaveform = removeEmptyCells(spikes.rawWaveform);
        spikes.maxWaveformCh(toRemove) = [];
    end
    end
end
%% filter by UID input
if ~isempty(UID)
        [toRemove] = ~ismember(spikes.UID,UID);
    spikes.UID(toRemove) = [];
    for r = 1:length(toRemove)
        if toRemove(r) == 1
         spikes.times{r} = [];
         spikes.region{r} = [];
        end
    end
    spikes.times = removeEmptyCells(spikes.times);
    spikes.region = removeEmptyCells(spikes.region);
    spikes.cluID(toRemove) = [];
    spikes.shankID(toRemove) = [];
    
    if getWaveforms
    for r = 1:length(toRemove)
        if toRemove(r) == 1
         spikes.rawWaveform{r} = [];
        end
    end
    spikes.rawWaveform = removeEmptyCells(spikes.rawWaveform);
    spikes.maxWaveformCh(toRemove) = [];
    end
end

%% Generate spindices matrics
spikes.numcells = length(spikes.UID);
for cc = 1:spikes.numcells
    groups{cc}=spikes.UID(cc).*ones(size(spikes.times{cc}));
end
if spikes.numcells>0
    alltimes = cat(1,spikes.times{:}); groups = cat(1,groups{:}); %from cell to array
    [alltimes,sortidx] = sort(alltimes); groups = groups(sortidx); %sort both
    spikes.spindices = [alltimes groups];
end

%% Check if any cells made it through selection
if isempty(spikes.times) | spikes.numcells == 0
    spikes = [];
end

