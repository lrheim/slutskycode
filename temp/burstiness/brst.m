
function   all_su_bursts=single_unit_bursts(data,data_h, isiThr, min_spikes_per_burst) % usually (data, 20 (ms), 2) %I added data_h and data_n
%%%%All burst functions,except for "find_short_bursts" are here, sequently
%data - basic data struct including information regarding recording time, number of units, spike times etc.
%min_ISI - min inter-spike interval in ms for spikes to be considered a burst
%min_spikes_per_burst - min number of spikes for a burst to be accepted
%% preallocations
spktimes = data; % change to seconds
cellfun(@max, spktimes, 'uni', false)
recLen = data_h; % units must be as spktimes


isiThr = 0.02;  % units must be as spktimes
binsize = 3600;  
% bins
nbins = 24;
nunits = length(spktimes); % get from spktimes

% initialize. change recLen according to binsize
sep_unit_spikes = cell(recLen, nunits); % I am thinking theat maxunit fuu hours gives the numcet og hours the uni "exsits" in the recording
all_burst_data = cell(recLen, nunits);
mean_spikes_in_burst = zeros(recLen, nunits);

mean_burst_duration = zeros(recLen, nunits);
mean_in_burst_freq = zeros(recLen, nunits);
mean_percent_spikes_in_bursts = zeros(recLen, nunits);
mean_IBI = zeros(recLen, nunits);
mean_short_bursts = zeros(recLen, nunits);
mean_burst_freq = zeros(recLen, nunits);
mean_norm_burst_freq= zeros(recLen, nunits);

%% make cell array of spikes per unit per time
for ibin=1:recLen
    for u=1:nunits
        [r] = find(spktimes{u}(:)>3600*(ibin-1) & spktimes{u}(:)<3600*ibin); % I think 1200 is becuse the calculation is only over the first 20 min of each hour
        sep_unit_spikes{ibin,u} = spktimes{u}(r);
    end
end
%%
for ibin=1:recLen
    
    for u=1:nunits
        spikes = sep_unit_spikes{ibin,u}(:);
        [burst_data] = single_burst_detect(spikes, isiThr, min_spikes_per_burst);
        all_burst_data{ibin,u} = burst_data;
        mean_spikes_in_burst(ibin,u) = mean(burst_data.spikes_in_burst);
%         spikes_in_bursts.(my_field)= [spikes_in_bursts.(my_field);burst_data.spikes_in_burst];
        mean_burst_duration(ibin,u) = mean(burst_data.burst_duration);
        mean_in_burst_freq(ibin,u) = mean(burst_data.in_burst_freq);
        mean_percent_spikes_in_bursts(ibin,u) = mean(burst_data.percent_spikes_in_bursts);
        mean_IBI(ibin,u) = mean(burst_data.IBI)/1000; %%%% divided by 1000 so that the answer will be in seconds
        mean_short_bursts(ibin,u) = mean(burst_data.short_bursts);
        mean_burst_freq(ibin,u) = mean(burst_data.burst_freq);
        mean_norm_burst_freq(ibin,u)= mean(burst_data.norm_burst_freq);
    end
end
%% remove non-bursting units
for u=1:nunits
    if all(mean_burst_freq(:,u)<0.004)
        mean_spikes_in_burst(:,u) = NaN;
        mean_burst_duration(:,u) = NaN;
        mean_in_burst_freq(:,u) = NaN;
        mean_percent_spikes_in_bursts(:,u) = 0; %%chaned NaN to 0
        mean_IBI(:,u) = NaN;
        mean_short_bursts(:,u) = mean(burst_data.short_bursts);
        mean_burst_freq(:,u) = NaN;
        mean_norm_burst_freq(:,u)= NaN;
        
    end
end
all_su_bursts.mean_spikes_in_burst = mean_spikes_in_burst;

all_su_bursts.mean_burst_duration = mean_burst_duration;
all_su_bursts.mean_in_burst_freq = mean_in_burst_freq;
all_su_bursts.mean_percent_spikes_in_bursts = mean_percent_spikes_in_bursts;
all_su_bursts.mean_percent_spikes_in_bursts( isnan(all_su_bursts.mean_percent_spikes_in_bursts)) =0; %%Added on 21/1/19 by Max  
all_su_bursts.mean_IBI = mean_IBI;
all_su_bursts.mean_burst_freq = mean_burst_freq;
all_su_bursts.mean_norm_burst_freq = mean_norm_burst_freq;
end


%%
function [burst_data]=single_burst_detect(spikes, min_ISI, min_spikes_per_burst)
ISI=diff(spikes);
[r]= find(ISI<=min_ISI);
bs=[];
for i=1:numel(r)
   
    bs(i)=r(i);
    if ~isequal(i,1) % start from the seconed ISI
        while isequal(r(i-1), (r(i)-1)) %%in bs-nullyfies the indices of the ISIs that belong to the same burst , except for the first ISI of each burst.
            bs(i)=0;
            i=i+1;
            if i>=numel(r)
                break
            end
        end
    end
end
if ~isempty(bs);
    bs_r=find(bs);
    bs=bs(bs_r);%bs is now the indices of the first ISI of each burst
    be=zeros(numel(bs),1);%
    for i=1:numel(bs)
        if isempty(find(ISI(bs(i):numel(ISI))>min_ISI)) %if there are no too-long ISIs since the i's burst begining, so be(i) is all the ISIs (one long burst). Important if the ISI ends with a burst, for example.
            be(i)=numel(ISI);
        else
            be(i)=(find(ISI(bs(i):numel(ISI))>min_ISI, 1, 'first'))+(bs(i))-1;
        end
    end
end
%%
%%single_burst_stats;
if ~isempty(bs)
    burst_spike_num = [bs' be];
    spikes_in_burst = diff(burst_spike_num,1,2)+1;%number of ISI in burst
    [short_bursts, filt_burst_spike_num, filt_spikes_in_burst]= find_short_bursts(min_spikes_per_burst, burst_spike_num,  spikes_in_burst);
    burst_times(:,1) = spikes(filt_burst_spike_num(:,1));
    burst_times(:,2) = spikes(filt_burst_spike_num(:,2));
    burst_duration = diff(burst_times,1,2)*1000; 
    in_burst_freq = filt_spikes_in_burst./(burst_duration/1000); 
    percent_spikes_in_bursts = (sum(filt_spikes_in_burst)/numel(spikes));
    
    burst_freq = numel(burst_duration)/3600; %me: again 1200 because of the 20 min
    if isempty(burst_times) || size(burst_times,1)==1
        IBI=[];
    else
        for b=1:size(burst_times,1)-1
            IBI(b,1) = 1000*(burst_times(b+1,1)- burst_times(b,2));
        end
        
    end
    burst_data.burst_spike_num = filt_burst_spike_num;
    burst_data.burst_times = burst_times;
    burst_data.spikes_in_burst = filt_spikes_in_burst;
    burst_data.burst_duration = burst_duration;
    burst_data.in_burst_freq = in_burst_freq;
    burst_data.percent_spikes_in_bursts = percent_spikes_in_bursts;
    burst_data.IBI = IBI;

    burst_data.short_bursts=short_bursts;
    burst_data.burst_freq = burst_freq;
    burst_data.norm_burst_freq= burst_freq/(numel(spikes)/3600);
else
    burst_data.burst_spike_num = [];
    burst_data.burst_times = [];
    burst_data.spikes_in_burst = [];
    burst_data.burst_duration = [];
    burst_data.in_burst_freq = [];
    burst_data.percent_spikes_in_bursts = [];
    burst_data.IBI = [];
    burst_data.short_bursts = [];
    burst_data.burst_freq = 0;
    burst_data.norm_burst_freq= 0;
end
%%
%%
end