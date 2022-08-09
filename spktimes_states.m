
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% session
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'forceDef', true, 'forceL', true, 'saveVar', true);      
basepath = session.general.basePath;
[~, basename] = fileparts(basepath);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calc brsts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load data
varsFile = ["spikes"; "datInfo"; "sleep_states"; "fr"; "units"];
varsName = ["spikes"; "datInfo"; "ss"; "fr"; "units"];
v = getSessionVars('basepaths', {basepath}, 'varsFile', varsFile,...
    'varsName', varsName);

sstates = [1, 4, 5];
stateNames = v(1).ss.info.names;
bins = v(1).ss.stateEpochs(sstates);

% mfr in states
mfrStates = cellfun(@(x) mean(x, 2), v.fr.states.fr, 'uni', false);
mfrStates = cell2mat(mfrStates(sstates));

% select vars and units
brstVar = ["freqOfNorm"; "freqOf"; "freqIn"; "spkprct"];
unitIdx = v.units.rs' & v.fr.mfr > prctile(v.fr.mfr, 50);
unitIdx = v.units.rs';

% spike timing metrics
st = spktimes_metrics('spikes', v.spikes, 'sunits', [],...
    'bins', bins, 'forceA', true, 'saveVar', true, 'fullA', false);

% brst (mea)
brst = spktimes_meaBrst(v.spikes.times, 'binsize', [], 'isiThr', 0.02,...
    'minSpks', 3, 'saveVar', true, 'force', true, 'bins', bins);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% simulate gain ratio for various brst params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

minSpks = [2 : 2 : 10];
isiThr = [0.1];

clear b 
for ithr = 1 : length(minSpks)
    b(ithr) = spktimes_meaBrst(v.spikes.times, 'binsize', [], 'isiThr', isiThr,...
        'minSpks', minSpks(ithr), 'saveVar', false, 'force', true, 'bins', bins);
end

clear gfactor
for ithr = 1 : length(minSpks)
    for ivar = 1 : length(brstVar)
        vec1 = b(ithr).(brstVar{ivar})(1, :)';
        vec2 = b(ithr).(brstVar{ivar})(2, :)';
        gfactor.(brstVar{ivar})(:, ithr) = (vec2 - vec1) ./ sum([vec1, vec2]')';
    end
end

% -------------------------------------------------------------------------
% plot gain factor of vars as a function of brst params

fh = figure;
th = tiledlayout(1, length(brstVar), 'TileSpacing', 'Compact');
title(th, num2str(isiThr))
for ivar = 1 : length(brstVar)
    axh = nexttile;
    dataMat = gfactor.(brstVar{ivar})(unitIdx, :);
    plot_boxMean(dataMat, 'clr', 'k', 'allPnts', false)
    title(brstVar{ivar})
    ylabel('GainFactor')
    xticklabels(split(num2str(minSpks)))
    xlabel('minSpks')
end


% -------------------------------------------------------------------------
% plot mean value of var per state, for each brst param

fh = figure;
th = tiledlayout(1, length(minSpks) + 1, 'TileSpacing', 'Compact');

% mfr
axh = nexttile;
plot_boxMean(mfrStates(unitIdx, :), 'clr', 'k', 'allPnts', false)
set(gca, 'yscale', 'log')
ylabel('MFR [Hz]')
xticklabels(stateNames(sstates))

% brst var 
ivar = 2;
for ithr = 1 : length(minSpks)
    axh = nexttile;
    dataMat = b(ithr).(brstVar{ivar})(:, unitIdx)';
    plot_boxMean(dataMat, 'clr', 'k', 'allPnts', false)
    set(gca, 'yscale', 'log')
    ylabel(brstVar{ivar})
    title(num2str(minSpks(ithr)))
    xticklabels(stateNames(sstates))
end


%%%
fh = figure;
% plot(mfrStates(:, 1), mfrStates(:, 2), '.', 'MarkerSize', 20)
plot(mfrStates(:, 2), v.fr.states.gain(4, :), '.', 'MarkerSize', 20)


% -------------------------------------------------------------------------
% predicition: prcnt spks in brsts should be correlated w/ mfr gain factor
fh = figure;
th = tiledlayout(2, 2, 'TileSpacing', 'Compact');

xval = b(1).spkprct(2, unitIdx);

axh = nexttile;
yval = mfrStates(unitIdx, 1);
plot(xval, yval, '.', 'MarkerSize', 20)
xlim([0 100])
xlabel('Spks In Brsts [%]')
ylim([0 2])
ylabel('MFR in AW')
p = polyfit(xval, yval, 1);
yfit = polyval(p, xval);
hold on
plot(xval, yfit, '--r')

axh = nexttile;
yval = mfrStates(unitIdx, 2);
plot(xval, yval, '.', 'MarkerSize', 20)
xlim([0 100])
xlabel('Spks In Brsts [%]')
ylim([0 2])
ylabel('MFR in NREM')
p = polyfit(xval, yval, 1);
yfit = polyval(p, xval);
hold on
plot(xval, yfit, '--r')

axh = nexttile;
axh.Layout.TileSpan = [1, 2];
yval = v.fr.states.gain(4, unitIdx);
plot(xval, yval, '.', 'MarkerSize', 20)
xlim([0 100])
xlabel('Spks In Brsts [%]')
ylabel('MFR gain')


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spktimes metrics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sstates = [1, 4, 5];
stateNames = v.ss.info.names;
bins = v.ss.stateEpochs(sstates);

stVar = ["royer"; "doublets"; "lidor"; "mizuseki"; "cv2"];

clear gfactor
for ivar = 1 : length(stVar)
    vec1 = st.(stVar{ivar})(1, :)';
    vec2 = st.(stVar{ivar})(2, :)';
    gfactor.(stVar{ivar}) = (vec2 - vec1) ./ sum([vec1, vec2]')';
end


fh = figure;
th = tiledlayout(1, 2, 'TileSpacing', 'Compact');
axh = nexttile;
plot_boxMean(v.fr.states.gain(4, unitIdx)', 'clr', 'k', 'allPnts', true)
ylabel('GainFactor')

axh = nexttile;
dataMat = [cell2nanmat(struct2cell(gfactor), 2)];
plot_boxMean(dataMat(unitIdx, :), 'clr', 'k', 'allPnts', true)
ylabel('GainFactor')
xticklabels(stVar)


ivar = 3;
fh = figure;
plot(st.(stVar{1})(1, unitIdx)', v.fr.states.gain(4, unitIdx)', '.', 'MarkerSize', 20)



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% multi-sessions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

basepaths = {
    'D:\Data\lh96\lh96_220121_090213';...
    'D:\Data\lh98\lh98_211224_084528';...
    'D:\Data\lh100\lh100_220405_100406';...
    'D:\Data\lh107\lh107_220509_095738'};
nfiles = length(basepaths);

% load data
varsFile = ["spikes"; "datInfo"; "sleep_states"; "fr"; "units";...
    "st_metrics"; "st_brst"];
varsName = ["spikes"; "datInfo"; "ss"; "fr"; "units"; "st"; "brst"];
v = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
    'varsName', varsName);

% state params
sstates = [1, 4, 5];
stateNames = v(1).ss.info.names;

% analyze
for ifile = 1 : nfiles
    
    basepath = basepaths{ifile};
    cd(basepath)
    
    % states
    bins = v(ifile).ss.stateEpochs(sstates);
    
    % spike timing metrics
    st = spktimes_metrics('spikes', v(ifile).spikes, 'sunits', [],...
        'bins', bins, 'forceA', true, 'saveVar', true, 'fullA', false);

    % brst (mea)
    brst = spktimes_meaBrst(v(ifile).spikes.times, 'binsize', [], 'isiThr', 0.1,...
        'minSpks', 8, 'saveVar', true, 'force', true, 'bins', bins);
end

% cat
fr = catfields([v(:).fr], 'catdef', 'symmetric');
st = catfields([v(:).st], 'catdef', 'long');
units = catfields([v(:).units], 'catdef', 'long');
brst = catfields([v(:).brst], 'catdef', 'long');

% select units
unitIdx = units.rs;

% calc gain factor of burst freq and mfr
vec1 = brst.freqOf(1, unitIdx)';
vec2 = brst.freqOf(2, unitIdx)';
brstGf = (vec2 - vec1) ./ sum([vec1, vec2]')';

vec1 = fr.states.mfr(unitIdx, 1)';
vec2 = fr.states.mfr(unitIdx, 4)';
mfrGf = (vec2 - vec1) ./ sum([vec1, vec2]')';

% -------------------------------------------------------------------------
% plot correlation of mfr / brst with their gain factor
fh = figure;
th = tiledlayout(1, 2, 'TileSpacing', 'Compact');

axh = nexttile;
ydata = fr.states.gain(4, unitIdx);
ydata = mfrGf;
xdata = fr.states.mfr(unitIdx, 1);
plot(xdata, ydata, '.', 'MarkerSize', 20)
set(gca, 'xscale', 'log')
xlabel('MFR in AW [Hz]')
ylabel('Gain Factor (NREM - AW)')

axh = nexttile;
ydata = brstGf;
xdata = brst.freqOf(1, unitIdx);
plot(xdata, ydata, '.', 'MarkerSize', 20)
set(gca, 'xscale', 'log')
xlabel('Burst Frequency [Hz]')
ylabel('Gain Factor (NREM - AW)')

% -------------------------------------------------------------------------
% plot correlation of mfr gain factor w/ brst freq
fh = figure;
th = tiledlayout(1, 2, 'TileSpacing', 'Compact');

axh = nexttile;
ydata = fr.states.gain(4, unitIdx);
ydata = mfrGf;
xdata = fr.states.mfr(unitIdx, 1);
plot(xdata, ydata, '.', 'MarkerSize', 20)
set(gca, 'xscale', 'log')
xlabel('MFR in AW [Hz]')
ylabel('Gain Factor (NREM - AW)')

axh = nexttile;
ydata = mfrGf;
xdata = brst.freqOf(1, unitIdx);
plot(xdata, ydata, '.', 'MarkerSize', 20)
set(gca, 'xscale', 'log')
xlabel('Burst Frequency [Hz]')
ylabel('Gain Factor (NREM - AW)')

% -------------------------------------------------------------------------
% plot correlation of mfr w/ brst freq in AW and NREM
fh = figure;
th = tiledlayout(1, 2, 'TileSpacing', 'Compact');

axh = nexttile;
xdata = fr.states.mfr(unitIdx, 1);
ydata = brst.freqOf(1, unitIdx);
plot(xdata, ydata, '.', 'MarkerSize', 20)
set(gca, 'xscale', 'log')
set(gca, 'yscale', 'log')
xlabel('MFR in AW [Hz]')
ylabel('Burst Freq. in AW (Hz)')
xlim([0.001, 10])
ylim([0.00001, 1])

axh = nexttile;
xdata = fr.states.mfr(unitIdx, 2);
ydata = brst.freqOf(2, unitIdx);
plot(xdata, ydata, '.', 'MarkerSize', 20)
set(gca, 'xscale', 'log')
set(gca, 'yscale', 'log')
xlabel('MFR in NREM [Hz]')
ylabel('Burst Freq. in NREM (Hz)')
xlim([0.001, 10])
ylim([0.00001, 1])

% -------------------------------------------------------------------------
% mfr and brst freq across states
fh = figure;
th = tiledlayout(1, 2, 'TileSpacing', 'Compact');

axh = nexttile;
ydata = fr.states.mfr(unitIdx, [1, 4, 5]);
plot_boxMean(ydata, 'clr', 'k', 'allPnts', false)
ylabel('MFR [Hz]')
set(gca, 'yscale', 'log')
xticklabels(stateNames(sstates))

axh = nexttile;
ydata = brst.freqOf(:, unitIdx)';
plot_boxMean(ydata, 'clr', 'k', 'allPnts', false)
set(gca, 'yscale', 'log')
ylabel('MFR [Hz]')
xticklabels(stateNames(sstates))

% -------------------------------------------------------------------------
% percent spikes in bursts across states
fh = figure;
th = tiledlayout(1, 2, 'TileSpacing', 'Compact');

axh = nexttile;
ydata = brst.nspks(:, unitIdx)';
plot_boxMean(ydata, 'clr', 'k', 'allPnts', false)
ylabel('No. Spikes per Burst')
% set(gca, 'yscale', 'log')
xticklabels(stateNames(sstates))

axh = nexttile;
ydata = brst.spkprct(:, unitIdx)';
plot_boxMean(ydata, 'clr', 'k', 'allPnts', false)
ylabel('Spikes in Burst [%]')
% set(gca, 'yscale', 'log')
xticklabels(stateNames(sstates))





% -------------------------------------------------------------------------


% get mfr in states
mfr = cellfun(@(x) mean(x, 2), fr.states.fr, 'uni', false);
clear mfrStates
for istate = 1 : length(sstates)
    mfrStates(:, istate) = vertcat(mfr{:, sstates(istate)});
end

% select units
brsty = mean(st.lidor, 1, 'omitnan');
unitBrsty = brsty > prctile(brsty(units.rs), 50);
unitMfr = fr.mfr > prctile(fr.mfr(units.rs), 50);
unitIdx = unitBrsty & units.rs;

% plot
fh = figure;
th = tiledlayout(1, 2, 'TileSpacing', 'Compact');

% mfr of all rs units
axh = nexttile;
plot_boxMean(mfrStates(units.rs, :), 'clr', 'k', 'allPnts', false)
set(gca, 'yscale', 'log')
ylabel('MFR [Hz]')
xticklabels(stateNames(sstates))

% mfr of only bursty units
axh = nexttile;
ivar = 1;
plot_boxMean(mfrStates(unitIdx, :), 'clr', 'k', 'allPnts', false)
set(gca, 'yscale', 'log')
ylabel('MFR [Hz]')
xticklabels(stateNames(sstates))

