classdef MockTimelineClock < hw.TLOutputClock
    % A TLOutputClock whose init opens no DAQ session, so tests can check
    % how Timeline treats an enabled output.
    methods
        function init(~, ~)
        end
    end
end
