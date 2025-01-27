function [clipped_discharges, tstamps] = extract_discharges(obj,time_marg,accepted)
    % extract IED discharges according to requested margins around.
    % Only extract accepted discharges!
    % them.
    %
    %   INPUTS:
    %       obj                - ied object calling this method.
    %       time_marg          - positive scalar, requested time window around each IED in [S].
    %                            If empty or not given, use marg in ied object (default).
    %       accepted           - logical vector, same size of ied.pos.
    %                            If not given, use accpepted in ied object (default).
    %   OUTPUT:
    %       tstamps            - time in [ms] for each sample in clipped_discharges
    %       clipped_discharges - discharge X sample, voltage response

    % use object margs if nothing else specefied
    if ~exist("time_marg","var") || isempty(time_marg)
        time_marg = obj.marg;
    end
    if ~exist("accepted","var")
        true_pos = obj.pos(obj.accepted);
    else
        true_pos = obj.pos(accepted);
    end
    % convert from time margings to samples
    margs = floor(time_marg * obj.fs); % margs [samples]; obj.marg [ms]

    % create time stamps to match margings
    tstamps = linspace(-time_marg, time_marg, margs * 2 + 1); % in [ms]

    % extract waveforms
    if isempty(true_pos)
        % deal with empty case - return empty
        clipped_discharges = [];
        tstamps = [];
    else
        clipped_discharges = nan(numel(true_pos), numel(tstamps));
        for iDischarges = 1:numel(true_pos)
            area2clip = (true_pos(iDischarges)-margs) : (true_pos(iDischarges) + margs);
            if max(area2clip) > length(obj.sig) || any(area2clip < 0)
                warning("IED_DATA:Extract_Discharges:Out_Of_Bound",...
                    "With time margins %g [Sec], discharge at sample %d is out of signal bound.\n" + ...
                    "Therefore, it is returned as nan. Consider using smaller margins.",...
                    time_marg, true_pos(iDischarges))
                clipped_discharges(iDischarges,:) = nan;
            else
                clipped_discharges(iDischarges,:) = obj.sig(area2clip);
            end
        end
    end
end