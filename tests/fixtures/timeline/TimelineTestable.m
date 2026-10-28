classdef TimelineTestable < hw.Timeline
    % Exposes hw.Timeline's protected methods to tests and swaps the DAQ
    % session for a MockTimelineSession, so no hardware is needed.
    properties
        ChannelsPerAdd = 1 % passed on to the mock session
    end
    methods
        function obj = TimelineTestable()
            obj.Outputs = []; % outputs open their own DAQ sessions
        end
        function s = mainSession(obj)
            s = obj.Sessions('main');
        end
        function callInit(obj)
            obj.init();
        end
        function prepareData(obj, nChannels, nSamples)
            % Mimics the state hw.Timeline/start leaves before acquisition
            obj.Data = struct('rawDAQData', zeros(nSamples, nChannels), ...
                'rawDAQSampleCount', 0);
            obj.LastTimestamp = -obj.SamplingInterval;
        end
        function callProcess(obj, data, timestamps)
            event = struct('Data', data, 'TimeStamps', timestamps);
            obj.process([], event);
        end
        function d = data(obj)
            d = obj.Data;
        end
    end
    methods (Access = protected)
        function s = newDaqSession(obj)
            s = MockTimelineSession();
            s.ChannelsPerAdd = obj.ChannelsPerAdd;
        end
    end
end
