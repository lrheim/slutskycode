
% questions for lidor

% (1) what creiteria do you use to exclude CCHs?
% (2) does it make sense that when converting to pairs, the output is sorted
% according to the target cell?
% (3) in cch_stg had to change roiMS to [nan 10]
% (4) our version of CCG.m receives spktimes in [s]
% (5) no function alines

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mea_analyze('basepath', pwd,...
    'winBL', [0, 120 * 60], 'graphics', true, 'forceA', false)

% calc ccg
acg_narrow_bnsz = 0.0005;
acg_narrow_dur = 0.1;
[acg_narrow, acg_narrow_tstamps] = CCG(mea.spktimes,...
    [], 'binSize', acg_narrow_bnsz,...
    'duration', acg_narrow_dur, 'norm', 'rate', 'Fs', 1 / mea.info.fs);

% params
winCalc = [0, 4 * 60 * 60];         % [s]
% winCalc = [0, Inf];                 % [s]
minSpks = 3000;

nunits = length(mea.spktimes);
npairs = nunits * nunits - nunits;
nspks = cellfun(@length, mea.spktimes, 'uni', true);
spkFS = mea.info.fs;

% convert a pair of units to an idx to stg outputs
cpair = [14, 17];
[~, ccIidx] = cidx2cpair(nunits, [], cpair);
% convert an idx to stg outputs into a pair of units
ccIidx = 11129;
[cpair, ~] = cidx2cpair(nunits, ccIidx, []);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% prepare spktimes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% create spktimes and labels in single vec format. limit spks to specified
% window
spkL = [];
spkT = [];
for iunit = 1 : nunits
    spkIdx = mea.spktimes{iunit} > winCalc(1) &...
        mea.spktimes{iunit} < winCalc(2);
    spkT = [spkT; mea.spktimes{iunit}(spkIdx)];
    spkL = [spkL; ones(sum(spkIdx), 1) * iunit];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get spk transmission gain
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% note that lidor probably uses a different version of CCG.m which requires
% spktimes in samples.
[eSTG1, eSTG2, act, sil, dcCCH, crCCH, cchbins] =...
    call_cch_stg(spkT * spkFS, spkL, spkFS);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% limit results
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear ccExc 
clear refExc

% limit results to pairs with enough counts in the raw cch
ccThr = 500;
ccBad = squeeze(sum(acg_narrow, 1)) < ccThr;
[ccExc(1, :), ccExc(2, :)] = find(ccBad);
[~, ccIdx] = cidx2cpair(nunits, [], ccExc');

% limit results to pairs with no refractory period
refThr = 5;
refTidx = round(length(acg_narrow_tstamps) / 2) - 1 :...
   round(length(acg_narrow_tstamps) / 2) + 1;
refBad = squeeze(sum(acg_narrow(refTidx, :, :))) < refThr;
[refExc(1, :), refExc(2, :)] = find(refBad);
[~, refIdx] = cidx2cpair(nunits, [], refExc');

% limit results according to stg ([ext, inh])
thrStg = [0, -Inf];
stgExcIdx = find(eSTG1 < thrStg(1) | isnan(eSTG1));
stgInhIdx = find(eSTG2 > -thrStg(2) | isnan(eSTG2));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get all remaining pairs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% excitatory pairs
rmvIdx = unique([ccIdx, refIdx, stgExcIdx]);
actExcluded = act;
actExcluded(rmvIdx) = 0;
excIdx = find(actExcluded);
fprintf('\nExcitatory: orig = %d, final = %d\n',...
    sum(act), length(excIdx))
excPair = cidx2cpair(nunits, excIdx, []);

% inhibitory pairs
rmvIdx = unique([ccIdx, refIdx, stgInhIdx]);
silExcluded = sil;
silExcluded(rmvIdx) = 0;
inhIdx = find(silExcluded);
fprintf('\nExcitatory: orig = %d, final = %d\n',...
    sum(act), length(inhIdx))
inhPair = cidx2cpair(nunits, inhIdx, []);


% compare to mono_res
sortrows(mono_res.sig_con_inhibitory, 2)
sortrows(mono_res.sig_con_excitatory, 2)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% excitatory synapses
npairsPlot = min([10, length(excIdx)]);
for ipair = 1 : npairsPlot
    cpair = excPair(ipair, :);   
    cidx = excIdx(ipair);
    clr = 'rb';
    plot_monoSyn('spktimes', mea.spktimes(cpair), 'wv', mea.wv(cpair, :),...
        'wv_std', mea.wv_std(cpair, :), 'clr', clr, 'fs', 10000,...
        'ccg2', dcCCH(:, cidx), 'stg', eSTG1(cidx), 'saveFig', false,...
        'units', cpair, 'ccg2_tstamps', cchbins * 1000)
end

% inhibitory synapses
npairsPlot = min([10, length(inhIdx)]);
for ipair = 1 : npairsPlot
    cpair = inhPair(ipair, :);   
    cidx = inhIdx(ipair);
    clr = 'rb';
    plot_monoSyn('spktimes', mea.spktimes(cpair), 'wv', mea.wv(cpair, :),...
        'wv_std', mea.wv_std(cpair, :), 'clr', clr, 'fs', 10000,...
        'ccg2', dcCCH(:, cidx), 'stg', eSTG2(cidx), 'saveFig', false,...
        'units', cpair, 'ccg2_tstamps', cchbins * 1000)
end




figure
subplot(1, 2, 1)
bar( cchbins, crCCH( :, ccIidx ), 1, 'FaceColor', Cdc, 'EdgeColor', 'none' );
set( gca, 'box', 'off', 'tickdir', 'out' )
xlabel( 'Time lag [s]' )
ylabel( 'Count' )
title( sprintf( 'rSTG: %0.5f  eSTG: %0.5f', [ NaN eSTG1( ccIidx ) ] ) )
subplot(1, 2, 2)
bar( cchbins, dcCCH( :, ccIidx ), 1, 'FaceColor', Cdc, 'EdgeColor', 'none' );
set( gca, 'box', 'off', 'tickdir', 'out' )
xlabel( 'Time lag [s]' )
ylabel( 'Count' )
title( sprintf( 'rSTG: %0.5f  eSTG: %0.5f', [ NaN eSTG1( ccIidx ) ] ) )



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% cell explorer
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mono_res = ce_MonoSynConvClick(spikes,'includeInhibitoryConnections',true/false); % detects the monosynaptic connections

spikes.times = mea.spktimes;
spikes.shankID = mea.ch;
spikes.cluID = [1 : length(mea.spktimes)];


mono_res = ce_MonoSynConvClick(spikes,...
    'includeInhibitoryConnections', true, 'epoch', [0 Inf]);

basepath = pwd;
[~, basename] = fileparts(basepath);
monofile = fullfile(basepath, [basename, '.mono_res.cellinfo.mat']);
save(monofile, 'mono_res');
setMatlabGraphics(true)
gui_MonoSyn(monofile);
load(monofile)
mono_res

cpair = [30, 45];

clr = 'rb';
plot_monoSyn('spktimes', mea.spktimes, 'swv', swv, 'units', cpair,...
    'clr', clr, 'fs', 10000)
