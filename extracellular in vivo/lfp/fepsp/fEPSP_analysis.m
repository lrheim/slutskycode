function fepsp = fEPSP_analysis(varargin)

% gets a fepsp struct and analyzes the traces according to protocol
% (currently io or stp, in the future maybe more). assumes fEPSPfromDat or
% WCP has been called beforehand.
%
% INPUT
%   fepsp       struct. see fEPSPfromDat or fEPSPfromWCP
%   basepath    string. path to .dat file (not including dat file itself)
%   dt          numeric. deadtime for exluding stim artifact
%   force       logical. force reload {false}.
%   saveVar     logical. save variable {1}.
%   saveFig     logical. save graphics {1}.
%   graphics    numeric. if 0 will not plot grpahics. if greater than
%               nspkgrp will plot all grps, else will plot only
%               selected grp {1000}.
%   vis         char. figure visible {'on'} or not ('off')
%   savename    char. name to save the variable by. By default will be
%               folder name from 'basepath' + .fepsp {[]}.
%   MainTets    Numeric vec, Main Tetrodes, choose waveform edge points only for them.
%               All other Tetrodes will use an avergage of the times
%               choosen for them, in the matching intensity. If empty or
%               any > fepsp.info.spkgrp, will treat all Tetrodes as important {[]}.
%   MinTimeTol  numeric scalar {5}. Time [ms] tolarence for the waveform minima
%               time point. When selecting the time for the waveform
%               minima, The function will look for each trace if there is a
%               lower point in the selected time distance (half in each
%               direction) from the selected time point. In each case, if
%               the tolarence cause the waveform minima to be before the
%               maxima, the maxima+1 will be choosen.
%
% CALLS
%   none
%
% OUTPUT
%   fepsp       struct with fields described below
%
% TO DO LIST
%   # Lior Da Marcas take over (done)
%   # Better warning msg to "Polynomial is not unique; degree >=number of data points"
%   # Add ablity to cheack diffrent time using LineChooseWin before saving?
%   # Add option to remove traces using LineChooseWin?
%   # Add option to re-analyse only some tetrodes?
%
% 16 oct 20 LH  UPDATES
% 02 Nov 20 LD  Change analysis from range on relevant window to
%               amplitude as 1st peak on waveArg, Change graphic to work
%               with that
% 05 Dec 20 LD  Change analysis from auto to user define Points via mini
%               GUI, add slope analysis, minor change graphics to comply
%               with this changes and to export maximazed view of graph.
%               Give option to caller to determine file name at saving
% 09 Dec 20 LD  Added MainTets, and now user choose waveform edge points
%               for each intensity per tetrode
% 28 Dec 20 LD  Change to GUI style, add option to move freely between Ints
%               and Tets, add option to remove & invert trace by GUI, add
%               time tolarence to minima point.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'fepsp', []);
addOptional(p, 'basepath', pwd);
addOptional(p, 'dt', 2, @isnumeric);
addOptional(p, 'force', false, @islogical);
addOptional(p, 'saveVar', true, @islogical);
addOptional(p, 'saveFig', true, @islogical);
addOptional(p, 'graphics', 1000);
addOptional(p, 'vis', 'on', @ischar);
addOptional(p, 'savename', [], @ischar);
addOptional(p, 'MainTets', [], @isnumeric);
addOptional(p, 'MinTimeTol', 5, @isnumeric);

parse(p, varargin{:})
fepsp = p.Results.fepsp;
basepath = p.Results.basepath;
dt = p.Results.dt;
force = p.Results.force;
saveVar = p.Results.saveVar;
saveFig = p.Results.saveFig;
graphics = p.Results.graphics;
vis = p.Results.vis;
savename = p.Results.savename;
MainTets = sort(p.Results.MainTets);
MinTimeTol = p.Results.MinTimeTol;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get params from fepsp struct
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[~, basename] = fileparts(basepath);
if isempty(savename)
    fepspname = [basename '.fepsp.mat'];
else
    fepspname = savename;
end

% try to load file if not in input
if isempty(fepsp)
    if exist(fepspname, 'file')
        load(fepspname)
    end
end
if isfield(fepsp, 'slope_10_50') && ~force
    load(fepspname)
    return
end

fs = fepsp.info.fs;
spkgrp = fepsp.info.spkgrp;
nspkgrp = length(spkgrp);
nfiles = length(fepsp.intens);
protocol = fepsp.info.protocol;
% make sure tstamps column vector
fepsp.tstamps = fepsp.tstamps(:);
tstamps = fepsp.tstamps;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% prepare for analysis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dt = round(dt / 1000 * fs);
switch protocol
    case 'io'
        % single pulse of 500 us after 30 ms. recording length 150 ms.
        % repeated once every 15 s. negative peak of response typically
        % 10 ms after stim.
        nstim = 1;
        [~, wvwin(1)] = min(abs(tstamps - 0));
        [~, wvwin(2)] = min(abs(tstamps - 30));
        wvwin(1) = wvwin(1) + dt;
    case 'stp'
        % 5 pulses of 500 us at 50 Hz. starts after 10 ms. recording length
        % 200 ms. repeated once every 30 s
        nstim = 5;
        
        % correct stim frequency
        if strcmp(fepsp.info.recSystem, 'oe') || strcmp(fepsp.info.recSystem, 'tdt')
            ts = fepsp.info.stimTs;
            ts = mean(ts(ts < 500)) / fs * 1000;
        elseif strcmp(fepsp.info.recSystem, 'wcp')
            ts = 20;
        end
        wvwin = round([10 : ts : 5 * ts; 30 : ts : 5 * ts + 10]' * fs / 1000);
        wvwin(:, 1) = wvwin(:, 1) + dt;
        wvwin(:, 2) = wvwin(:, 2) - dt;
end

% Prepere fepsp fields

% traceAvg      3d mat (tetrode x intensity x sample) of entire trace
fepsp.traceAvg  = nan(nspkgrp, nfiles, length(fepsp.tstamps));
% waves         2d cell (tetrode x intensity) where each cell contains the
%               waves (zoom in view of traces)
fepsp.waves     = cell(nspkgrp, nfiles);
% wavesAvg      3d mat (tetrode x intensity x sample) of waves (zoom in
%               view of trace), averages across traces. for io only
fepsp.wavesAvg  = nan(nspkgrp, nfiles, length(wvwin(1) : wvwin(2)));
% info.AnalysedTimePoints   3d mat (tetrode x intensity x stim), The time points user
%               choose for each stim. For each 2 of dim3  "columns", the first is the
%               start and the secound is the end of the area to analyse.
%               Time is from fepsp.tstamps.
fepsp.info.AnalysedTimePoints = nan(nspkgrp,nfiles,2*nstim);
% info.MainTets see in function Inputs explanation.
fepsp.info.MainTets = MainTets;
% fepsp.info.MinTimeTol see in function Inputs explanation.
fepsp.info.MinTimeTol = MinTimeTol;
% ampcell       2d array (tetrode x stim) where each cell contains the
%               amplitude/s for each trace
fepsp.ampcell   = cell(nspkgrp, nfiles);
% slopecell_10_50   2d array (tetrode x intensity) where each cell contains
%               the slope/s of 10% to 50% for each trace
fepsp.slopecell_10_50 = cell(nspkgrp, nfiles);
% slopecell_20_90   2d array (tetrode x intensity) where each cell contains
%               the slope/s of 20% to 90% for each trace
fepsp.slopecell_20_90 = cell(nspkgrp, nfiles);
% amp           2d (io) or 3d (stp) mat (tetrode x intensity x stim) of
%               amplitude averaged across traces
fepsp.amp   = nan(nspkgrp, nfiles, nstim);
% slope_10_50   2d (io) or 3d (stp) mat (tetrode x intensity x stim) of
%               slope 10% to 50% averaged across traces (STP not implanted!)
fepsp.slope_10_50 = nan(nspkgrp, nfiles, nstim);
% slope_20_90    2d (io) or 3d (stp) mat (tetrode x intensity x stim) of
%               slope 20% to 90% averaged across traces (STP not implanted!)
fepsp.slope_20_90 = nan(nspkgrp, nfiles, nstim);
% ampNorm       2d array of normalized amplitudes. for each trace the
%               responses are normalized to first response. these
%               normalized amplitudes. for
%               stp only
fepsp.ampNorm   = nan(nspkgrp, nfiles, nstim);
% facilitation  2d mat of average maximum normalized response. for stp only
fepsp.facilitation = nan(nspkgrp, nfiles);

fepsp = rmfield(fepsp, 'ampNorm');
The_10_50_20_90 = cell(nspkgrp,nfiles); %Slope ind for average waveforms (See later)
TimeFrameWindow = fepsp.tstamps(wvwin(1) : wvwin(2)); %Timeframe or responce
StartStimTimeIND = nan(nspkgrp,nfiles);
EndStimTimeINDBase = nan(nspkgrp,nfiles);
EndStimINDTrace = cell(nspkgrp,nfiles);

% Choose waveform edge points for Main Tets, and take an avarage of it for all others
if isempty(MainTets) || any(MainTets > nspkgrp) % If MainTets is empty or any is too big, take all
    MainTets = 1 : nspkgrp;
end

% Transform MinTimeTol to 2 way IND
MinINDTol = round(((MinTimeTol/1000)*fs)./2);

% Create fepsp.traceAvg, fepsp.waves & fepsp.wavesAvg
for j = 1:nspkgrp
    for i = 1:nfiles
        fepsp.traceAvg(j, i, :) = mean(fepsp.traces{j, i}, 2);
        fepsp.waves{j, i} = fepsp.traces{j, i}(wvwin(1) : wvwin(2), :);
        fepsp.wavesAvg(j, i, :) = mean(fepsp.waves{j, i}, 2);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create Analysis GUI
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Build Gui Base
AnalysisWin = figure('WindowState','maximized');
AnalysisWin.Tag = 'Main Window'; %We will use tags to locate our figures
yLimit = [min(fepsp.traces{MainTets(1), end}, [], 'all'),...
    max(fepsp.traces{MainTets(1), end}, [], 'all')];
ThePlot = plot(TimeFrameWindow,fepsp.traces{MainTets(1),nfiles}(wvwin(1) : wvwin(2), :));
ax = gca;
xlabel('Time [ms]')
ylabel('Amp [mV]')
title({sprintf('%s - T%d @ %duA',basename,MainTets(1),fepsp.intens(nfiles))...
    'Move green / red lines to start / end of each response accordingly'...
    'Press "Enter\return" to move to next intns'})
axis tight
ylim(yLimit*1.1)

% Create Movable Lines
XLims = xlim();
LineStartPos = linspace(XLims(1),XLims(2),2*nstim);
Colors = {'g','r'};
Pos = {'S','E'};
for ii = length(LineStartPos):-1:1
    ColorIND = mod(ii,2);
    ColorIND(ColorIND == 0) = 2;
    d(ii) = drawline('Position',[repmat(LineStartPos(ii),2,1) ylim()'],'InteractionsAllowed','translate','Color',Colors{ColorIND},...
        'Label',sprintf('%d%s t=%.1f',ceil(ii/2),Pos{ColorIND},LineStartPos(ii)));
end
Lis = addlistener(d,'MovingROI',@WriteLoc); %Listener for showing the time in lines lable

% Build Gui Buttons & Interactivity
cm = uicontextmenu();
TetStrings = split(num2str(1:nspkgrp));
for ii = MainTets
    TetStrings{ii} = sprintf('*%s*',TetStrings{ii});
end
NowTet = uicontrol(AnalysisWin,'Style','popupmenu','String',TetStrings,'Value',MainTets(1),...
    'Tooltip',sprintf('Tetrode Selection\n(* Marks the Main tets)'));
NowInt = uicontrol(AnalysisWin,'Style','popupmenu','String',split(num2str(fepsp.intens)),'Value',nfiles,'Tooltip','Intens Selection');
NowInt.Callback = @(~,~) SwitchTetInt(AnalysisWin,ax,NowTet,NowInt,'Int',cm,[d.Position]);
NowTet.Callback = @(~,~) SwitchTetInt(AnalysisWin,ax,NowTet,NowInt,'Tet',cm,[d.Position]);
AnalyseTetB = uicontrol(AnalysisWin,'Style','pushbutton','String','AnalyseTet','Callback',@(~,~) AnalyseTetrode([d.Position],NowTet.Value,NowInt.Value));
AnalyseAllB = uicontrol(AnalysisWin,'Style','pushbutton','String','Analyse All','Callback',@(~,~) AnalyseAll([d.Position],NowTet.Value,NowInt.Value));
SaveExitB = uicontrol(AnalysisWin,'Style','pushbutton','String','Save&Exit','Callback',@(~,~) SaveExit([d.Position],NowTet.Value,NowInt.Value,Lis));
align([AnalyseTetB,AnalyseAllB,SaveExitB,NowTet,NowInt],'Fixed',5,'bottom')
uimenu(cm,'Label','Remove Trace','Callback',@(~,~) RemoveTrace(NowInt.Value));
uimenu(cm,'Label','Invert Trace','Callback',@(~,~) InvertTrace(NowInt.Value));
for ii = 1:length(ThePlot)
    ThePlot(ii).UIContextMenu = cm;
    ThePlot(ii).Tag = num2str(ii);
end
AnalysisWin.CloseRequestFcn = @(~,~) closeMain(AnalysisWin,Lis);
AnalysisWin.KeyReleaseFcn =  @(~,evt) KeyPressfnc(evt,AnalysisWin,ax,NowTet,NowInt,cm,[d.Position],Lis);

%Help Passing Vars Between Callbacks
AnalysisWin.UserData.LastTet = NowTet.Value;
AnalysisWin.UserData.LastInt = NowInt.Value;
OpenFigs = AnalysisWin;

% All nested multiscope var:
% fepsp
% OpenFigs
% ThePlot
% MainTets
% TimeFrameWindow
% basename
% basepath
% StartStimTimeIND
% EndStimTimeINDBase
% EndStimINDTrace
% The_10_50_20_90
% vis
% MinINDTol
% saveVar
% saveFig
% dt

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Core Functions
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function AnalyseAndShow(j)
        % AnalyseAndShow(Tet to work on)
        % Make Analyse and create figure for requested tet
        nspkgrpInfnc = length(fepsp.info.spkgrp);
        nfilesInfnc = length(fepsp.intens);
        protocolInfnc = fepsp.info.protocol;
        EndStimINDAvg = nan(nspkgrpInfnc,nfilesInfnc);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Analysis
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        for nn = 1 : nfilesInfnc
            switch protocolInfnc
                case 'io'
                    % Amp is simply absolute Start point - End point
                    LinIND = sub2ind(size(fepsp.waves{j, nn}),EndStimINDTrace{j, nn},1:size(fepsp.waves{j, nn},2));
                    fepsp.ampcell{j, nn} = abs(fepsp.waves{j, nn}(StartStimTimeIND(j,nn),:) - fepsp.waves{j, nn}(LinIND));
                    
                    % Calculate  Each trace slopes
                    for kk = length(fepsp.ampcell{j, nn}):-1:1
                        % Find for each trace the closest points that define about 10%-50% & 20%-90% of the calculated amp.
                        % Can be vectorize relatively simply using 3d array if run time too slow (Unexpected).
                        AllPointsAmp = abs(fepsp.waves{j, nn}(StartStimTimeIND(j,nn),kk) - fepsp.waves{j, nn}(StartStimTimeIND(j,nn):EndStimINDTrace{j, nn}(kk),kk));
                        MinusMat = fepsp.ampcell{j, nn}(kk)*[0.1 0.5 0.2 0.9];
                        [~,Trace_10_50_20_90] = min(abs(AllPointsAmp-MinusMat),[],1);
                        % If there are both a significant biphasic between StartStim & EndStim, the lower precentage might be found after
                        % the higher one. Will break colon operator later. in this case, just flip them.
                        if Trace_10_50_20_90(1) > Trace_10_50_20_90(2)
                            Trace_10_50_20_90(1:2) = Trace_10_50_20_90(2:-1:1);
                        end
                        if Trace_10_50_20_90(3) > Trace_10_50_20_90(4)
                            Trace_10_50_20_90(3:4) = Trace_10_50_20_90(4:-1:3);
                        end
                        Trace_10_50_20_90 = Trace_10_50_20_90+StartStimTimeIND(j,nn)-1; %Match the indicies from small StartStim:EndStim window back to TimeFrameWindow.
                        
                        % Calculate Slope by fitting a line. Cannot be vectorize simply.
                        FitParams = polyfit(TimeFrameWindow(Trace_10_50_20_90(1) :...
                            Trace_10_50_20_90(2)),...
                            fepsp.waves{j, nn}(Trace_10_50_20_90(1) :...
                            Trace_10_50_20_90(2), kk), 1);
                        fepsp.slopecell_10_50{j, nn}(kk) = FitParams(1);
                        FitParams = polyfit(TimeFrameWindow(Trace_10_50_20_90(3) :...
                            Trace_10_50_20_90(4)),...
                            fepsp.waves{j, nn}(Trace_10_50_20_90(3) :...
                            Trace_10_50_20_90(4), kk), 1);
                        fepsp.slopecell_20_90{j, nn}(kk) = FitParams(1);
                    end
                    
                    %Redo on mean wave. Save closest points that define about 10%-50% & 20%-90% to avoid recalcuating for graphics
                    [~,EndStimINDAvg(j,nn)] = min(squeeze(fepsp.wavesAvg(j,nn,(EndStimTimeINDBase(j, nn) - MinINDTol):(EndStimTimeINDBase(j, nn) + MinINDTol))));
                    EndStimINDAvg(j,nn) = EndStimTimeINDBase(j, nn) + EndStimINDAvg(j,nn) - MinINDTol;
                    EndStimINDAvg(j,nn) = max(EndStimINDAvg(j,nn),StartStimTimeIND(j, i)+1); % Vs found point < start point bug, due to tolarence
                    fepsp.amp(j, nn) = abs(fepsp.wavesAvg(j, nn, StartStimTimeIND(j,nn)) - fepsp.wavesAvg(j, nn,EndStimINDAvg(j,nn)));
                    AllPointsAmp = squeeze(abs(fepsp.wavesAvg(j, nn, StartStimTimeIND(j,nn):EndStimINDAvg(j,nn)) - fepsp.wavesAvg(j, nn, StartStimTimeIND(j,nn))));
                    MinusMat = fepsp.amp(j, nn)*[0.1 0.5 0.2 0.9];
                    [~,The_10_50_20_90{j,nn}] = min(abs(AllPointsAmp-MinusMat),[],1);
                    if The_10_50_20_90{j,nn}(1) > The_10_50_20_90{j,nn}(2)
                        The_10_50_20_90{j,nn}(1:2) = The_10_50_20_90{j,nn}(2:-1:1);
                    end
                    if The_10_50_20_90{j,nn}(3) > The_10_50_20_90{j,nn}(4)
                        The_10_50_20_90{j,nn}(3:4) = The_10_50_20_90{j,nn}(4:-1:3);
                    end
                    The_10_50_20_90{j,nn} = The_10_50_20_90{j,nn}+StartStimTimeIND(j,nn)-1;
                    FitParams = polyfit(TimeFrameWindow(The_10_50_20_90{j,nn}(1) :...
                        The_10_50_20_90{j,nn}(2)),...
                        squeeze(fepsp.wavesAvg(j, nn, The_10_50_20_90{j, nn}(1) :...
                        The_10_50_20_90{j,nn}(2))), 1);
                    fepsp.slope_10_50(j, nn) = FitParams(1);
                    FitParams = polyfit(TimeFrameWindow(The_10_50_20_90{j,nn}(3) :...
                        The_10_50_20_90{j,nn}(4)),...
                        squeeze(fepsp.wavesAvg(j, nn, The_10_50_20_90{j, nn}(3) :...
                        The_10_50_20_90{j,nn}(4))),1);
                    fepsp.slope_20_90(j, nn) = FitParams(1);
                case 'stp'
                    % note; after reviewing the data it seems that specifically
                    % for stp maximum absolute value may be better than range
%                     for ii = 1 : nstim
%                         fepsp.ampcell{j, nn}(ii, :) =...
%                             range(fepsp.traces{j, nn}(wvwin(ii, 1) :  wvwin(ii, 2), :));
%                     end
%                     fepsp.ampNorm{j, nn} = fepsp.ampcell{j, nn} ./ fepsp.ampcell{j, nn}(1, :);
%                     fepsp.facilitation(j, nn) = mean(max(fepsp.ampNorm{j, nn}));
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % graphics
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        

        switch protocolInfnc
            case 'io'
                MatchFig = OpenFigs(strcmp({OpenFigs.Tag},sprintf('Analysed T%d',j)));
                if ishandle(MatchFig) %See if a figure for this tet is alrdy open. if so, recalculate it (to avoid mass figures)
                    fh = MatchFig;
                    set(groot,'CurrentFigure',fh);
                    hold(subplot(3, 1, 1),'off');
                else %Open a new fig
                    fh = figure('Visible', vis,'WindowState','maximized'); %Max window for better looking export
                    OpenFigs = [OpenFigs;fh];
                    sgtitle(sprintf('T#%d', j))
                    fh.Tag = sprintf('Analysed T%d',j);
                    uicontrol(fh,'Style','pushbutton','String','ExportFig','Callback',@(~,~) ExportAnfig(fh,j));
                    fh.CloseRequestFcn = @(~,~) closeAnalysedFig(fh,j);
                end               
                subplot(3, 1, 1) %Avarge Waveforms Marked
                plot(TimeFrameWindow, squeeze(fepsp.wavesAvg(j, :, :))','LineWidth',1)
                hold on
                % Mark on each waveform Start & End of analysed area
                Yind = sub2ind(size(fepsp.wavesAvg),ones(1,size(fepsp.wavesAvg,2))*j,1:size(fepsp.wavesAvg,2),StartStimTimeIND(j,:));
                plot(fepsp.info.AnalysedTimePoints(j,:,1:2:end),fepsp.wavesAvg(Yind),'*')
                Yind = sub2ind(size(fepsp.wavesAvg),ones(1,size(fepsp.wavesAvg,2))*j,1:size(fepsp.wavesAvg,2),EndStimINDAvg(j,:));
                plot(TimeFrameWindow(EndStimINDAvg(j,:)),fepsp.wavesAvg(Yind),'*')
                % Marker area in which slope was analysed
                for kk = 1:length(The_10_50_20_90(j,:))
                    P_10_50 = plot(TimeFrameWindow(The_10_50_20_90{j,kk}(1):The_10_50_20_90{j,kk}(2)),...
                        squeeze(fepsp.wavesAvg(j,kk,The_10_50_20_90{j,kk}(1):The_10_50_20_90{j,kk}(2))),'b','LineWidth',3);
                    P_10_50.Color(4) = 0.5;
                    P_10_50.Annotation.LegendInformation.IconDisplayStyle = 'off';
                    P_20_90 = plot(TimeFrameWindow(The_10_50_20_90{j,kk}(3):The_10_50_20_90{j,kk}(4)),...
                        squeeze(fepsp.wavesAvg(j,kk,The_10_50_20_90{j,kk}(3):The_10_50_20_90{j,kk}(4))),'y','LineWidth',3);
                    P_20_90.Color(4) = 0.5;
                    P_20_90.Annotation.LegendInformation.IconDisplayStyle = 'off';
                end
                axis tight
                ylim(ylim()*1.05)
                %                 yLimit = [min([fepsp.wavesAvg(:)]) max([fepsp.wavesAvg(:)])];
                %                 ylim(yLimit)
                xlabel('Time [ms]')
                ylabel('Voltage [mV]')
                legend([split(num2str(sort(fepsp.intens)));{'Amp measure point Stim Start'};{'Amp measure point Stim End'}],'Location','best','NumColumns',2)
                box off
                P_10_50.Annotation.LegendInformation.IconDisplayStyle = 'on';
                P_10_50.DisplayName = 'Slope Area 10%-50%';
                P_20_90.Annotation.LegendInformation.IconDisplayStyle = 'on';
                P_20_90.DisplayName = 'Slope Area 20%-90%';
                
                subplot(3, 1, 2) %Amplitude across ints (on avarge waveforms)
                %ampmat = cell2nanmat(fepsp.ampcell(i, :));
                %boxplot(ampmat, 'PlotStyle', 'traditional')
                bar(fepsp.amp(j,:))
                ylim([min(horzcat(fepsp.ampcell{:})) max(horzcat(fepsp.ampcell{:}))])
                xticklabels(split(num2str(sort(fepsp.intens))))
                xlabel('Intensity [uA]')
                ylabel('Amplidute [mV]')
                box off
                
                subplot(3, 1, 3) %Slope across ints (on avarge waveforms)
                bar([fepsp.slope_10_50(j,:);fepsp.slope_20_90(j,:)])
                xticklabels({'From 10% to 50%' 'From 20% to 90%'})
                xlabel('Measure area')
                ylabel('Slope [mV/mS]')
                legend([split(num2str(sort(fepsp.intens)))])
                box off
                
            case 'stp'
                errordlg('STP not ready')
                return
%                 fh = figure('Visible', vis);
%                 suptitle(sprintf('%s - T#%d', basename, nn))
%                 subplot(2, 1, 1)
%                 plot(fepsp.tstamps, squeeze(fepsp.traceAvg(nn, :, :))')
%                 axis tight
%                 yLimit = [min(min(horzcat(fepsp.traces{nn, :})))...
%                     max(max(horzcat(fepsp.traces{nn, :})))];
%                 ylim(yLimit)
%                 hold on
%                 plot(repmat([0 : ts : ts * 4]', 1, 2), yLimit, '--k')
%                 xlabel('Time [ms]')
%                 ylabel('Voltage [mV]')
%                 legend(split(num2str(sort(fepsp.intens))))
%                 box off
%                 
%                 subplot(2, 1, 2)
%                 for ii = 1 : length(fepsp.intens)
%                     x(ii, :) = mean(fepsp.ampNorm{nn, ii}, 2);
%                 end
%                 plot([1 : nstim], x)
%                 xticks([1 : nstim])
%                 xlabel('Stim No.')
%                 ylabel('Norm. Amplitude')
%                 yLimit = ylim;
%                 ylim([0 yLimit(2)])
        end
    end
    function SaveCurrentInts(LinesPos,j,i)
        % SaveCurrentInts(LinesPos,Tet,Int)
        % Saving the current LinesPos for the input Tet & Int
        nfilesInfnc = length(fepsp.intens);
        if isnumeric(LinesPos)
            LineXPos = LinesPos(1,1:2:end);
            % Calculate the closest Point that actually exist in data
            TimeFrameWindowMat = repmat(TimeFrameWindow, 1, nfilesInfnc);
            [~,StartStimTimeIND(j, i)] = min(abs(TimeFrameWindowMat - LineXPos(1:2:end)), [], 1);
            [~,EndStimTimeINDBase(j, i)] = min(abs(TimeFrameWindowMat - LineXPos(2:2:end)), [], 1);
            [~,EndStimINDTrace{j, i}] = min(fepsp.waves{j,i}(max((EndStimTimeINDBase(j, i) - MinINDTol),StartStimTimeIND(j, i)+1)... 
                :(EndStimTimeINDBase(j, i) + MinINDTol),:)); %The max make sure Tolarence doesn't take before StartStimTimeIND
            EndStimINDTrace{j, i} = EndStimTimeINDBase(j, i) + EndStimINDTrace{j, i} - MinINDTol;
            fepsp.info.AnalysedTimePoints(j,i,1:2:end) = TimeFrameWindow(StartStimTimeIND(j,i));
            fepsp.info.AnalysedTimePoints(j,i,2:2:end) = TimeFrameWindow(EndStimTimeINDBase(j,i));
        else
            switch LinesPos
                case 'MeanBetweenTet'
                    StartStimTimeIND(j, i) = round(mean(StartStimTimeIND(:, i),'omitnan'));
                    EndStimTimeINDBase(j, i) = round(mean(EndStimTimeINDBase(:, i),'omitnan'));
                    [~,EndStimINDTrace{j, i}] = min(fepsp.waves{j,i}(max((EndStimTimeINDBase(j, i) - MinINDTol),StartStimTimeIND(j, i)+1)...
                        :(EndStimTimeINDBase(j, i) + MinINDTol),:)); %The max make sure Tolarence doesn't take before StartStimTimeIND
                    EndStimINDTrace{j, i} = EndStimTimeINDBase(j, i) + EndStimINDTrace{j, i} - MinINDTol;
                    fepsp.info.AnalysedTimePoints(j,i,1:2:end) = TimeFrameWindow(StartStimTimeIND(j,i));
                    fepsp.info.AnalysedTimePoints(j,i,2:2:end) = TimeFrameWindow(EndStimTimeINDBase(j,i));
                case 'MeanInTet'
                    StartStimTimeIND(j, i) = round(mean(StartStimTimeIND(j, :),'omitnan'));
                    EndStimTimeINDBase(j, i) = round(mean(EndStimTimeINDBase(j, :),'omitnan'));
                    [~,EndStimINDTrace{j, i}] = min(fepsp.waves{j,i}(max((EndStimTimeINDBase(j, i) - MinINDTol),StartStimTimeIND(j, i)+1):...
                        (EndStimTimeINDBase(j, i) + MinINDTol),:)); %The max make sure Tolarence doesn't take before StartStimTimeIND
                    EndStimINDTrace{j, i} = EndStimTimeINDBase(j, i) + EndStimINDTrace{j, i} - MinINDTol;
                    fepsp.info.AnalysedTimePoints(j,i,1:2:end) = TimeFrameWindow(StartStimTimeIND(j,i));
                    fepsp.info.AnalysedTimePoints(j,i,2:2:end) = TimeFrameWindow(EndStimTimeINDBase(j,i));
            end
        end
    end
    function ExportAnfig(fh,CurrentTet)
        % Export the Analyse fig (fh) when requested
        figpath = fullfile(basepath, 'graphics');
        mkdir(figpath)
        figname = [figpath '\' basename '_fepsp_t' num2str(CurrentTet)];
        export_fig(fh,figname, '-tif', '-r300', '-transparent')
    end
    function PlotANew(ax,WantedTetNum,WantedIntNum,cm)
        % PlotANew(Ax to plot in,WantedTetNum,WantedIntNum,contextmenu to place in plots)
        tstampsfnc = fepsp.tstamps;
        [~, wvwinfnc(1)] = min(abs(tstampsfnc - 0));
        [~, wvwinfnc(2)] = min(abs(tstampsfnc - 30));
        wvwinfnc(1) = wvwinfnc(1) + dt;
        hold(ax,'on')
        delete(ThePlot)
        ThePlot = plot(TimeFrameWindow,fepsp.traces{WantedTetNum,WantedIntNum}(wvwinfnc(1) : wvwinfnc(2), :));
        % The 3 above lines keep the lines and the figure the same, but switch the traces
        for aa = 1:length(ThePlot) % Add the contextmenu to the plots
            ThePlot(aa).UIContextMenu = cm;
            ThePlot(aa).Tag = num2str(aa);
        end
        title(ax,{sprintf('%s - T%d @ %duA',basename,WantedTetNum,fepsp.intens(WantedIntNum))...
            'Move green / red lines to start / end of each response accordingly'...
            'Press "Enter\return" to move to next intns'}) %Change title to match new Ints & Tets
    end
    function closeAnalysedFig(fh,CurrentTet)
        % Close the Analyse fig (fh) when requested. Export it if saveFig in true
        if saveFig
           ExportAnfig(fh,CurrentTet)
        end
        OpenFigs(strcmp({OpenFigs.Tag},fh.Tag)) = [];
        delete(fh)
    end
    function closeMain(AnalysisWin,Lis)
        % Close the Main window (AnalysisWin) and delete the Lines. Save
        % fepsp if saveVar is true. Put the analysed fepsp in base in any case.
        % Listener, just in case. If windows of analyesed tets are still open, close them.
        if saveVar
            save(fepspname,'fepsp')
        end
        NonMain = OpenFigs(~strcmp({OpenFigs.Tag},'Main Window') & ishandle(OpenFigs));
        if any(ishandle(NonMain))
            for nn = 1:length(NonMain)
                closeAnalysedFig(fh,str2double(NonMain(nn).Tag(end)))
            end
        end
        assignin('base','fepsp',fepsp) 
        delete(Lis)
        delete(AnalysisWin)
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Buttons & Interactivity Functions
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function WriteLoc(obj,evt)
        %Callback function to the listner, just change the time written in
        %line lable when moving it
        CurrXPos = evt.CurrentPosition(1);
        obj.Label = [obj.Label(1:(find(obj.Label == '='))), sprintf('%.1f',CurrXPos)];
    end
    function AnalyseTetrode(LinesPos,CurrentTet,CurrentInt)
        % Bureaucratic function to take care of diffrent cases of what was already analysed.
        SaveCurrentInts(LinesPos,CurrentTet,CurrentInt)
        if any(isnan(StartStimTimeIND(CurrentTet,:))) % Tet is not full
            MissingInts = find(isnan(StartStimTimeIND(CurrentTet,:)));
            if all(any(~isnan(StartStimTimeIND),1)) %Other Tets have Ints, so we can avg between
                Status = questDlg({'Not all of this Tet''s intens have a inputed time point' ...
                    'Do you want to use an avg of The others Tet existing ones?'},'Missing tet intens','Yes','No & Cancel','Yes');
                if ismember(Status,{'No & Cancel',''})
                    return
                end
                for kk = MissingInts
                    SaveCurrentInts('MeanBetweenTet',CurrentTet,kk)
                end
            elseif ~all(isnan(StartStimTimeIND(CurrentTet,:))) %As we have at least one ints in this Tet (Unrelevant check), we can avg inside the tet to fill the missing.
                Status = questDlg({'Not all of this Tet''s intens have a inputed time point, and other Tets havn''t been filled fully as well.' ...
                    'Do you want to use an avg of this Tet existing ones?'},'Missing tet intens','Yes','No & Cancel','Yes');
                if ismember(Status,{'No & Cancel',''})
                    return
                end
                for kk = MissingInts
                    SaveCurrentInts('MeanInTet',CurrentTet,kk)
                end
            end
        end
        AnalyseAndShow(CurrentTet)
    end
    function AnalyseAll(LinesPos,CurrentTet,CurrentInt)
        % Will Analyse all the tets in a signal press. Function is for the
        % Bureaucratic part.
        % Logic: If not all Main Tets are full but some do, avg the full
        %        ones and remove the non full from Main Tets.
        %        If there is no full Main Tets, but every Main Tet have
        %        some Ints, avg inside tet for each of them.
        SaveCurrentInts(LinesPos,CurrentTet,CurrentInt)
        MissingMainTets = any(isnan(StartStimTimeIND(MainTets,:)),2);
        if any(MissingMainTets)
            FullTets = all(~isnan(StartStimTimeIND(MainTets,:)),2);
            HaveSomeInts = any(~isnan(StartStimTimeIND(MainTets,:)),2);
            if any(FullTets)
                Status = questDlg({'Only some of Main Tets intens have a full - inputed time point' ...
                    'Do you want to use an avg of The full Main Tets to fill the missing?'...
                    'Any previus input to them will be overwriten, and they will be removen from Main Tets'},'Missing tet intens','Yes','No & Cancel','Yes');
                if ismember(Status,{'No & Cancel',''})
                    return
                end
                MainTets(~FullTets) = [];
            elseif all(HaveSomeInts)
                Status = questDlg({'All of Main Tets have unfilled intens time point.' ...
                    'Do you want to use an avg of each Main Tet existing ones?'},'Missing tet intens','Yes','No & Cancel','Yes');
                if ismember(Status,{'No & Cancel',''})
                    return
                end
                for nn = MainTets
                    MissingInts = find(isnan(StartStimTimeIND(nn,:)));
                    for kk = MissingInts
                        SaveCurrentInts('MeanInTet',nn,kk)
                    end
                end
            else
                errordlg('Not enough time point in Main tets have been inputed to analyse. aborting')
                return
            end
        end
        for nn = find(~ismember(1:size(StartStimTimeIND,1),MainTets))
            for kk = 1:length(fepsp.intens)
                SaveCurrentInts('MeanBetweenTet',nn,kk)
            end
        end
        for nn = 1:size(StartStimTimeIND,1)
            AnalyseAndShow(nn)
        end
    end
    function SaveExit(LinesPos,CurrentTet,CurrentInt,Lis)
        % Analyse all, export according to saveVar & saveFig and close
        vis = 'off';
        AnalyseAll(LinesPos,CurrentTet,CurrentInt)
        NotMain = OpenFigs(~strcmp({OpenFigs.Tag},'Main Window'));
        for nn = 1:size(StartStimTimeIND)
            closeAnalysedFig(NotMain(nn),nn)
        end
        closeMain(OpenFigs(strcmp({OpenFigs.Tag},'Main Window')),Lis);
    end 
    function RemoveTrace(NowInt)
        % Use right click to remove trace from all Tets.
       nspkgrpInfnc = length(fepsp.info.spkgrp);
       Trace = gco;
       TraceNum = str2double(Trace.Tag);
       Status = questDlg({'Are you sure you want to remove trace?' 'This is Parament for the struct'},'Removal Confirm','Yes','No','Yes');
       if ismember(Status,{'No',''})
           return
       end
       for nn = 1:nspkgrpInfnc
           fepsp.info.rm{nn,NowInt} = TraceNum;
           fepsp.traces{nn,NowInt}(:,TraceNum) = [];
           fepsp.waves{nn, NowInt}(:,TraceNum) = [];
           fepsp.traceAvg(nn, NowInt, :) = mean(fepsp.traces{nn, NowInt}, 2);
           fepsp.wavesAvg(nn, NowInt, :) = mean(fepsp.waves{nn, NowInt}, 2);
       end
       delete(Trace);
    end
    function InvertTrace(NowInt)
       % Invert Trace in all Tets
       nspkgrpInfnc = length(fepsp.info.spkgrp);
       Trace = gco;
       TraceNum = str2double(Trace.Tag);
       for nn = 1:nspkgrpInfnc
           fepsp.traces{nn,NowInt}(:,TraceNum) = -fepsp.traces{nn,NowInt}(:,TraceNum);
           fepsp.waves{nn, NowInt}(:,TraceNum) = -fepsp.waves{nn, NowInt}(:,TraceNum);
           fepsp.traceAvg(nn, NowInt, :) = mean(fepsp.traces{nn, NowInt}, 2);
           fepsp.wavesAvg(nn, NowInt, :) = mean(fepsp.waves{nn, NowInt}, 2);
       end
       Trace.YData = -Trace.YData; 
    end
    function SwitchTetInt(AnalysisWin,ax,NowTet,NowInt,Parm,cm,LinesPos,Lis)
        % Bureaucratic, manage the trasfer between plots.
        switch Parm
            case 'Next'
                SaveCurrentInts(LinesPos,NowTet.Value,NowInt.Value)
                if NowInt.Value == 1
                    if all(~isnan(StartStimTimeIND(MainTets,:)),'all')
                        Status = questDlg('Finished Main Tets. Analyse All?','Finished Main','Yes & Exit','Yes','No','Yes');
                        switch Status
                            case  "Yes"
                                AnalyseAll(LinesPos,NowTet.Value,NowInt.Value)
                            case 'Yes & Exit'
                                SaveExit(LinesPos,NowTet.Value,NowInt.Value,Lis)
                                return
                        end
                    end
                    if NowTet.Value == max(MainTets)
                       NowTet.Value = min(MainTets);
                    else
                       NowTet.Value = MainTets(find(MainTets == NowTet.Value)+1);
                    end
                    NowInt.Value = length(NowInt.String);
                    NowTet.BackgroundColor = 'g';
                    NowInt.BackgroundColor = 'g';
                    pause(0.2)
                    NowTet.BackgroundColor = 'w';
                    NowInt.BackgroundColor = 'w';
                    PlotANew(ax,NowTet.Value,NowInt.Value,cm)
                else
                    NowInt.Value = NowInt.Value-1;
                    PlotANew(ax,NowTet.Value,NowInt.Value,cm)
                    NowInt.BackgroundColor = 'g';
                    pause(0.2)
                    NowInt.BackgroundColor = 'w';
                end
                AnalysisWin.UserData.LastTet = NowTet.Value;
                AnalysisWin.UserData.LastInt = NowInt.Value;
            case 'Tet'
                if ~ismember(NowTet.Value,MainTets)
                    Status = questDlg({'Selected Tet is not in Main tets. Do you want to add it?'...
                        'If not, it will get overwriten when choosing ''Analyse All'',''Save&Exit'' or ''x'''},'Not Main Test','Yes','No','Cancle','Yes');
                    switch Status
                        case 'Yes'
                            MainTets = sort([MainTets NowTet.Value]);
                            NowTet.String{NowTet.Value} = ['*' NowTet.String{NowTet.Value} '*'];
                        case {'Cancle' ''}
                            NowTet.Value = AnalysisWin.UserData.LastTet;
                            NowTet.BackgroundColor = 'g';
                            pause(0.2)
                            NowTet.BackgroundColor = 'w';
                            return
                    end
                end
                Status = questDlg('Save current Trace?','Save current?','Yes','No','Yes');
                switch Status
                    case 'Yes'
                        SaveCurrentInts(LinesPos,AnalysisWin.UserData.LastTet,NowInt.Value)
                    case ''
                        msgBox('Cancled, Aborting move')
                        NowTet.Value = AnalysisWin.UserData.LastTet;
                        NowTet.BackgroundColor = 'g';
                        pause(0.2)
                        NowTet.BackgroundColor = 'w';
                        return
                end
                PlotANew(ax,NowTet.Value,NowInt.Value,cm)
                AnalysisWin.UserData.LastTet = NowTet.Value;
                figure(AnalysisWin);
            case 'Int'
                Status = questDlg('Save current Trace?','Save current?','Yes','No','Yes');
                switch Status
                    case 'Yes'
                        SaveCurrentInts(LinesPos,NowTet.Value,AnalysisWin.UserData.LastInt)
                    case ''
                        msgBox('Cancled, Aborting move')
                        NowInt.Value = AnalysisWin.UserData.LastInt;
                        NowInt.BackgroundColor = 'g';
                        pause(0.2)
                        NowInt.BackgroundColor = 'w';
                        return
                end
                PlotANew(ax,NowTet.Value,NowInt.Value,cm)
                AnalysisWin.UserData.LastInt = NowInt.Value;
                figure(AnalysisWin);
        end
    end
    function KeyPressfnc(evt,AnalysisWin,ax,NowTet,NowInt,cm,LinesPos,Lis)
        % Just Make sure that next is activated only by "return"
        if evt.Character == 13
            SwitchTetInt(AnalysisWin,ax,NowTet,NowInt,'Next',cm,LinesPos,Lis)
        end
    end
    
end

% EOF