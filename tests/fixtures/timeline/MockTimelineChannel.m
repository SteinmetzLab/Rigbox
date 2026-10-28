classdef MockTimelineChannel < handle
    % Stands in for a daq channel object returned by the add*Channel methods.
    properties
        Kind % 'analog' or 'counter'
        Device
        ID
        MeasurementType
        TerminalConfig = 'Default'
        EncoderType = 'X1'
    end
    methods
        function obj = MockTimelineChannel(kind, device, id, meas)
            obj.Kind = kind;
            obj.Device = device;
            obj.ID = id;
            obj.MeasurementType = meas;
        end
    end
end
