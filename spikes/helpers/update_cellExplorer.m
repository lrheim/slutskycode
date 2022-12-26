function update_cellExplorer(basepath)

% applies certain corrections to cell explorer

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% prep data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cd(basepath)
[~, basename] = fileparts(basepath);
spktimesfile = fullfile(basepath, [basename, '.spktimes.mat']);
spikesfile = fullfile(basepath, [basename, '.spikes.cellinfo.mat']);
session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'forceDef', true, 'forceL', false, 'saveVar', false);      
spkgrp = session.extracellular.spikeGroups.channels;
ngrps = length(spkgrp);

load(spktimesfile, 'spktimes')
load(spikesfile, 'spikes')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% corrections
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% correct shank id (ce assigns according to maximum waveform across all
% channels)
shankid = nan(1, length(spikes.shankID));
cnt = 1;
for igrp = 1 : ngrps
    clu = loadNS('datatype', 'clu', 'session', session, 'grpid', igrp);
    nclu = length(unique(clu(clu > 1)));
    shankid(cnt : cnt + nclu - 1) = ones(1, nclu) * igrp;
    cnt = cnt + nclu;
end
spikes.shankID = shankid;

% add spike sorting stats
spikes.spksDetected = cellfun(@length, spktimes, 'uni', true);
for igrp = 1 : ngrps
    grpidx = spikes.shankID == igrp;
    spikes.spksSU(igrp) = length(vertcat(spikes.times{grpidx}));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save updates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

save(spikesfile, 'spikes')

end

% EOF