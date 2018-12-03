function preprocWrapper()

% this is a wrapper for preprocessing extracellular data.
% contains calls for various functions.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'D:\VBshare\chr7_Teri_Day1_7_8_18_bl1_mrg';
basename = 'chr7_Teri_Day1_7_8_18_bl1_mrg';

class = cellclass(basename);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 1: ddt to dat
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
mapch = [1, 3, 5, 7, 2, 4, 6, 8, 9, 11, 13, 15, 10, 12, 14, 16];
rmvch = [];

ddt2dat(basepath, mapch, rmvch)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 2: load spikes and LFP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

noPrompts = false;
forceReload = true;
% sessionInfo = getSessionInfo(basepath);

spikes = getSpikes('basePath', basepath, 'noPrompts', noPrompts, 'forceReload', forceReload);

lfp = lh_GetLFP(sessionInfo.channels, 'basePath', basepath);

spikes.sessionDur = lfp.duration;

fet = getFet(basepath);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 3: review clusters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

plotCluster(spikes)

PCAfet = 1 : 12;
for i = 1 : length(fet)
    nclu = unique(fet{i}(:,18));
    nclu = length(nclu(nclu > 1));
    L{i} = zeros(nclu, 1);
    iDist{i} = zeros(nclu ,1);
    for j = 1 : nclu
        cluidx = find(fet{i}(:, end) == spikes.cluID(j));
        [L{i}(j) iDist{i}(j)] = cluDist(fet{i}(:, PCAfet), cluidx);
    end
end

% concatenate cell
L = cat(1, L{:});
iDist = cat(1, iDist{:});

% ISI contamination
ISIcontam = zeros(length(spikes.UID), 1);
for i = 1 : length(spikes.UID)
    ISIcontam(i) = sum(diff(spikes.times{i}) < 0.003) / length(spikes.times{i}) * 100;
end

for i = 1 : length(spikes.UID)
    ISIcontam(i) = histcounts(diff(spikes.times{i}), [0 0.002]) /...
        histcounts(diff(spikes.times{i}), [0 0.02]);
end



% plot
figure
ax = gca;
scatter3((L), (iDist), (ISIcontam), '*')
% line(([0.05 0.05]), ax.YLim)
% line(ax.XLim, ([50 50]))
xlabel('L ratio')
ylabel('Isolation Distance')
zlabel('ISI contamination [%]')
hold on

Lval = [0 5];
iDistval = [50 ax.YLim(2)];
ISIval = [0 1];

v = [Lval(1), iDistval(1), ISIval(1); Lval(2) iDistval(1) ISIval(1); Lval(2) iDistval(2) ISIval(1); Lval(1) iDistval(2) ISIval(1);...
    Lval(1), iDistval(1), ISIval(2); Lval(2) 50 ISIval(2); Lval(2) iDistval(2) ISIval(2); Lval(1) iDistval(2) ISIval(2)];
f = [1 2 3 4; 1 4 8 5; 3 4 8 7; 2 3 7 6;];
p = patch('Faces', f, 'Vertices', v);
p.FaceAlpha = 0.1;
axis tight
xlim([0 30])
% view(3)

h = histogram([diff(spikes.times{i}) diff(spikes.times{i}) * -1], bins);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 4: concatenates spikes from different sessions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parentdir = 'D:\VBshare';
structname = 'spikes.cellinfo';
spikes = catstruct(parentdir, structname);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 5: CCH temporal dynamics 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 6: cell classification based on waveform
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[CellClass] = cellclass(parentdir, spikes);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 4: calculate mean firing rate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



spkcount = spkcount(spikes);

f = fieldnames(spikes);
 for i = 1:length(f)
    spikes.(f{i}) = spikes2.(f{i})
 end

