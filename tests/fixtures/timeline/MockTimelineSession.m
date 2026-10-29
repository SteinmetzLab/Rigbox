classdef MockTimelineSession < handle
    % Stands in for a daq.Session: records the channels Timeline adds to it.
    properties
        Rate
        IsContinuous
        NotifyWhenDataAvailableExceeds
        Channels = MockTimelineChannel.empty
        % Channels each add* call creates; more than 1 mimics a channel ID
        % that names several channels
        ChannelsPerAdd = 1
    end
    methods
        function ch = addAnalogInputChannel(obj, dev, id, meas)
            ch = obj.add(MockTimelineChannel('analog', dev, id, meas));
        end
        function ch = addCounterInputChannel(obj, dev, id, meas)
            ch = obj.add(MockTimelineChannel('counter', dev, id, meas));
        end
        function stop(~)
        end
    end
    methods (Access = private)
        function ch = add(obj, ch)
            for k = 1:obj.ChannelsPerAdd
                obj.Channels(end+1) = ch;
            end
        end
    end
end
