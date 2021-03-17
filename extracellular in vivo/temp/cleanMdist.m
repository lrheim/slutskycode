
% removes spikes that are rvds based on fet / mDist

% DEPENDENCIES
%   Diagnostic Feature Explorer for Kullback�Leibler divergence
%   (relativeEntropy)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% params
basepath = 'D:\Data\lh86\lh86_210311_100153';
cd(basepath)
[~, basename] = fileparts(basepath);

session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'force', true, 'saveVar', true);
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;

psamp = [];
grps = [];

% files params
sniplength = ceil(1.6 * 10^-3 * fs);
win = [-(floor(sniplength / 2) - 1) floor(sniplength / 2)];   
precision = 'int16'; % for dat file. size of one data point in bytes
nbytes = class2bytes(precision); 

if isempty(psamp)
    psamp = round(sniplength / 2);
end
if isempty(grps)
    grps = 1 : length(spkgrp);
end
ngrps = length(grps);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% go over groups and clus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for j = 1 : ngrps
    
    grp = grps(j);
    grpchans = spkgrp{j};
    
    % ---------------------------------------------------------------------
    % load data for neurosuite files
    
    % clu
    cluname = fullfile([basename '.clu.' num2str(grp)]);
    fid = fopen(cluname, 'r');
    nclu = fscanf(fid, '%d\n', 1);
    clu = fscanf(fid, '%d\n');
    rc = fclose(fid);
    if rc ~= 0 || isempty(clu)
        warning(['failed to read clu ' num2str(j)])
    end
    nspks(j) = length(clu);
    uclu = unique(clu);
    
    % res 
    resname = fullfile([basename '.res.' num2str(grp)]);
    fid = fopen(resname, 'r');
    res = fscanf(fid, '%d\n');
    rc = fclose(fid);
    if rc ~= 0 || isempty(res)
        warning(['failed to read res ' num2str(j)])
    end
    
    % spk
    spkname = fullfile([basename '.spk.' num2str(grp)]);
    fid = fopen(spkname, 'r');
    spk = fread(fid, 'int16');
    spk = reshape(spk, length(grpchans), sniplength, nspks(j)); 
    rc = fclose(fid);
    if rc ~= 0 || isempty(spk)
       warning(['failed to read spk ' num2str(j)])
    end
     
    % fet
    npca = 3;
    nfet = npca * length(spkgrp{j});
    fetname = fullfile([basename '.fet.' num2str(grp)]);  
    fid = fopen(fetname, 'r');
    nFeatures = fscanf(fid, '%d', 1);
    fet = fscanf(fid, '%f', [nFeatures, inf])';
    fet = fet(:, 1 : nfet);
    rc = fclose(fid);
    if rc ~= 0 || isempty(fet)
        warning(['failed to read fet ' num2str(j)])
    end
    
    for iclu = 1 : 30
        if uclu(iclu) == 0
            continue
        end
        cluidx = find(clu == uclu(iclu));
        
        clear fetclu newfet
%         fetclu = fet(cluidx, :);        % from fet files
        % recalculate pca
        for ichan = 1 : length(grpchans)
            [~, pcFeat] = pca(permute(spk(ichan, :, cluidx), [3, 2, 1]));
            newfet(:, ichan * 3 - 2 : ichan * 3) = pcFeat(:, 1 : 3);
        end
        fetclu = newfet;                % new calculation
        
        % mdist
        mDist = mahal(fet, fet(cluidx, :));
        mCluster = mDist(cluidx); % mahal dist of spikes in cluster        
        
        % rpv
        ref = ceil(0.002 * fs);
        rpv = find(diff([0; res(cluidx)]) < ref);
        
        % bins for mDist
        bins = linspace(0, max(mCluster), 500);
        binIntervals = [0 bins(1 : end - 1); bins]';
        
        normmode = 'cdf';
        for ifet = 1 : nfet
            [spkpdf, binedges] = histcounts(fetclu(:, ifet), nbins, 'Normalization', normmode);
            [rpvpdf] = histcounts(fetclu(rpv, ifet), 'BinEdges', binedges, 'Normalization', normmode);
            
            histogram(rpvpdf - spkpdf, 100)
            figure
            plot(spkpdf)
            hold on
            plot(rpvpdf)
            plot(movmean(rpvpdf - spkpdf, 3))

            bincents = (binedges(2 : end) + edges(1 : (end - 1))) / 2;

%             kl(ifet) = kldiv(bincents', spkpdf' + eps, rpvpdf' + eps, 'sym');
            
            phat = mle(spkpdf, 'distribution', 'Half Normal')
            pd = fitdist(mdistpdf', 'HalfNormal')
        end
        
%         [mdistpdf] = histcounts(mCluster, 'Normalization', normmode);

        
        % test removal
        nrmv = histcounts(fetclu(:, 2), 'BinEdges', [-2500 -200]);
        rpvrmv = histcounts(fetclu(rpv, 2), 'BinEdges', [-2500 -200]);
        muOrig = (length(rpv)) / (length(cluidx)) * 100;
        mu = (length(rpv) - rpvrmv) / (length(cluidx) - nrmv) * 100;
        
        % graphics
        figure
        [nsub] = numSubplots(nfet + 1);
        nbins = 100;
        normmode = 'probability';
        for ifet = 1 : nfet
            subplot(nsub(1), nsub(2), ifet)
            histogram(fetclu(:, ifet), nbins,...
                'FaceAlpha', 0.4, 'LineStyle', 'none', 'Normalization', normmode)
            hold on
            histogram(fetclu(rpv, ifet), nbins,...
                'FaceAlpha', 0.4, 'LineStyle', 'none', 'Normalization', normmode)
            sh = scatter(fetclu(rpv, ifet), mean(get(gca, 'YLim')) *...
                ones(length(rpv), 1), 'k');
            set(sh, 'Marker', 'x')
%             ylim([0 1])
            title(sprintf('fet #%d, KL = %.2f', ifet, kl(ifet)))
            if ifet == 1
                legend({'All spks', 'RPVs'})
            end
        end
        subplot(nsub(1), nsub(2), ifet + 1)
        histogram(mCluster, nbins, 'FaceAlpha', 0.4, 'LineStyle', 'none',...
            'Normalization', normmode)
        hold on
        histogram(mCluster(rpv), nbins,...
            'FaceAlpha', 0.4, 'LineStyle', 'none', 'Normalization', normmode)
        sh = scatter(mCluster(rpv), mean(get(gca, 'YLim')) *...
            ones(length(rpv), 1), 'k');
        set(sh, 'Marker', 'x')
        title('mDist')
        suptitle(['clu #', num2str(iclu)])
        
    end
      
    % ---------------------------------------------------------------------
    % save files
    
 
end
     
% EOF

% -------------------------------------------------------------------------
% load and inspect rvds in parallel to mancur
j = 2;      % spkgrp
% clu
cluname = fullfile([basename '.clu.' num2str(j)]);
fid = fopen(cluname, 'r');
nclu = fscanf(fid, '%d\n', 1);
clu = fscanf(fid, '%d\n');
rc = fclose(fid);
if rc ~= 0 || isempty(clu)
    warning(['failed to read clu ' num2str(j)])
end
nspks(j) = length(clu);
uclu = unique(clu);

% res
resname = fullfile([basename '.res.' num2str(j)]);
fid = fopen(resname, 'r');
res = fscanf(fid, '%d\n');
rc = fclose(fid);
if rc ~= 0 || isempty(res)
    warning(['failed to read res ' num2str(j)])
end

ref = ceil(0.002 * fs);
for iclu = 1 : nclu
        if uclu(iclu) == 0 || uclu(iclu) == 1
            continue
        end
        cluidx = find(clu == uclu(iclu));
    
        % rvd
        rpv = find(diff([0; res(cluidx)]) < ref);
        mu(iclu) = length(rpv) / length(cluidx) * 100;
 end