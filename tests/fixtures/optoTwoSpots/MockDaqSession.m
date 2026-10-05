classdef MockDaqSession < handle
    % Stands in for a daq.Session: records what command() queues.
    properties
        queued = []
        started = 0
    end
    methods
        function queueOutputData(obj, data)
            obj.queued = data;
        end
        function startBackground(obj)
            obj.started = obj.started + 1;
        end
        function stop(~)
        end
    end
end
