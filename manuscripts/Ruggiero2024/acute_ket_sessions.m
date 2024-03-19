
function [basepaths, v, nfiles] = ketInVivo_sessions(expType)

% loads data from specified experiments
% [basepaths, v, nfiles] = ketInVivo_sessions({'acsf', 'ket', 'ket10', 'ket60'});

basepaths = {};
if any(strcmp(expType, 'acsf'))
    basepaths = [basepaths...
        {'F:\Data\lh93\lh93_210811_102035'},...
        {'F:\Data\lh95\lh95_210824_083300'},...
        {'F:\Data\lh96\lh96_211201_070100'},...
        {'F:\Data\lh99\lh99_211218_090630'},...
        {'F:\Data\lh100\lh100_220405_100406'},...
        {'F:\Data\lh107\lh107_220509_095738'},...
        ];
    %     {'F:\Data\Processed\lh96\lh96_211124_073800'},...
    %     {'F:\Data\lh93\lh93_210811_102035'},...
    %     {'F:\Data\lh99\lh99_211218_090630'},...
end

if any(strcmp(expType, 'ket'))
    basepaths = [basepaths...
        {'F:\Data\lh93\lh93_210813_110609'},...
        {'F:\Data\lh95\lh95_210825_080400'},...
        {'F:\Data\lh96\lh96_211204_084200'},...
        {'F:\Data\lh100\lh100_220403_100052'},...
        {'F:\Data\lh107\lh107_220501_102641'},...
        ];
    % {'F:\Data\lh99\lh99_220119_090035'},...
    %     {'F:\Data\lh96\lh96_211126_072000'},...
    %     {'F:\Data\lh96\lh96_211202_070500'},...
end

if any(strcmp(expType, 'ket10'))
    basepaths = [basepaths...
        {'F:\Data\lh81\lh81_210204_190001'},...
        {'F:\Data\lh96\lh96_211206_070400'},...
        {'F:\Data\lh98\lh98_211224_084528'},...
        {'F:\Data\lh106\lh106_220512_102302'},...
        {'F:\Data\lh107\lh107_220512_102302'},...
        ];
    % F:\Data\lh81\lh81_210204_190001   inj 0zt
end

if any(strcmp(expType, 'ket60'))
    basepaths = [basepaths...
        {'F:\Data\lh81\lh81_210206_190000'},...
        {'F:\Data\lh98\lh98_211224_084528'},...
        {'F:\Data\lh106\lh106_220512_102302'},...
        {'F:\Data\lh107\lh107_220512_102302'},...
        ];
    % F:\Data\lh81\lh81_210204_190000       inj 0zt
    % F:\Data\lh86\lh86_210311_100153       only 8 hr rec
end

nfiles = length(basepaths);
varsFile = ["fr"; "fr_bins"; "spikes"; "datInfo"; "session";...
    "units"; "sleep_states"; "psd_bins"; "spec"; "swv_metrics";...
    "st_metrics"; "st_brst"];
varsName = ["fr"; "frBins"; "spikes"; "datInfo"; "session";...
    "units"; "ss"; "psdBins"; "spec"; "swv";...
    "st"; "brst"];
v = getSessionVars('basepaths', basepaths, 'varsFile', varsFile,...
    'varsName', varsName);

end