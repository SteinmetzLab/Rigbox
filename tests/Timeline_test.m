classdef Timeline_test < matlab.unittest.TestCase
    % Tests hw.Timeline channel setup and data handling without hardware.
    % TimelineTestable swaps the DAQ session for a MockTimelineSession; the
    % chrono and other outputs are not exercised here (they need a DAQ).

    methods (TestClassSetup)
        function addMock(tc)
            here = fileparts(mfilename('fullpath'));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(here, 'fixtures', 'timeline')));
        end
    end

    methods (Access = private)
        function tl = dragontailLike(~)
            % Inputs as configured on dragontail (2026-10), including unused
            % inputs that share a channel with used ones.
            tl = TimelineTestable();
            tl.DaqSampleRate = 2000;
            tl.addInput('rotaryEncoder', 'ctr1', 'Position', [], 1, true);
            tl.addInput('galvoX', 'ai1', 'Voltage', 'SingleEnded', 1, true);
            tl.addInput('pump1', 'ai1', 'Voltage', 'SingleEnded', 1, false);
            tl.addInput('photodiode', 'ai6', 'Voltage', 'SingleEnded', 1, true);
            tl.addInput('odorSensor', 'ai6', 'Voltage', 'SingleEnded', 1, false);
            tl.addInput('lickDetector', 'ctr2', 'EdgeCount', [], 1, true);
        end
    end

    methods (Test)
        %% Existing behaviour (regression)
        function initAddsUsedChannelsInUseInputsOrder(tc)
            tl = tc.dragontailLike();
            tl.callInit();
            s = tl.mainSession();
            tc.verifyEqual({s.Channels.ID}, {'ai0', 'ctr1', 'ai1', 'ai6', 'ctr2'});
            tc.verifyEqual({s.Channels.Kind}, ...
                {'analog', 'counter', 'analog', 'analog', 'counter'});
            tc.verifyEqual(s.Rate, 2000);
            tc.verifyTrue(s.IsContinuous);
        end

        function initAssignsArrayColumns(tc)
            tl = tc.dragontailLike();
            tl.callInit();
            cols = containers.Map({tl.Inputs.name}, {tl.Inputs.arrayColumn});
            tc.verifyEqual(cols('chrono'), 1);
            tc.verifyEqual(cols('rotaryEncoder'), 2);
            tc.verifyEqual(cols('galvoX'), 3);
            tc.verifyEqual(cols('photodiode'), 4);
            tc.verifyEqual(cols('lickDetector'), 5);
            tc.verifyEqual(cols('pump1'), -1);
            tc.verifyEqual(cols('odorSensor'), -1);
        end

        function initFollowsUseInputsNotInputsOrder(tc)
            tl = tc.dragontailLike();
            tl.UseInputs = {'chrono', 'photodiode', 'galvoX'};
            tl.callInit();
            tc.verifyEqual({tl.mainSession().Channels.ID}, {'ai0', 'ai6', 'ai1'});
            tc.verifyEqual(tl.Inputs(strcmp({tl.Inputs.name}, 'photodiode')).arrayColumn, 2);
        end

        function initSetsChannelOptions(tc)
            tl = tc.dragontailLike();
            tl.addInput('pd2', 'ai5', 'Voltage', 'diff');
            tl.callInit();
            ch = tl.mainSession().Channels;
            tc.verifyEqual(ch(strcmp({ch.ID}, 'ai5')).TerminalConfig, 'Differential');
            tc.verifyEqual(ch(strcmp({ch.ID}, 'ctr1')).EncoderType, 'X4');
            tc.verifyEqual(ch(strcmp({ch.ID}, 'ctr1')).MeasurementType, 'Position');
            tc.verifyEqual(ch(strcmp({ch.ID}, 'ctr2')).MeasurementType, 'EdgeCount');
        end

        function processStoresAnalogDataUnchanged(tc)
            tl = tc.dragontailLike();
            tl.callInit();
            tl.prepareData(5, 10);
            data = rand(4, 5) * 5;
            tl.callProcess(data, (0:3)' / 2000);
            d = tl.data();
            tc.verifyEqual(d.rawDAQSampleCount, 4);
            tc.verifyEqual(d.rawDAQData(1:4, :), data);
        end

        function processDetectsDiscontinuity(tc)
            tl = tc.dragontailLike();
            tl.callInit();
            tl.prepareData(5, 10);
            tl.callProcess(zeros(2, 5), (0:1)' / 2000);
            tc.verifyError(@() tl.callProcess(zeros(2, 5), (3:4)' / 2000), ...
                'Rigbox:hw:Timeline:discontinuity');
        end

        %% addInput validation
        function addInputRejectsDuplicateName(tc)
            tl = tc.dragontailLike();
            tc.verifyError(@() tl.addInput('galvoX', 'ai9', 'Voltage'), ...
                'Rigbox:hw:Timeline:duplicateInput');
        end

        function addInputRejectsUnknownMeasurement(tc)
            tl = tc.dragontailLike();
            tc.verifyError(@() tl.addInput('x', 'ai9', 'Frequency'), ...
                'Rigbox:hw:Timeline:unknownMeasurement');
        end

        function initRejectsUnknownMeasurementInInputs(tc)
            % Inputs edited directly bypass addInput; master skipped such an
            % input but still gave it a column, shifting every later column
            tl = tc.dragontailLike();
            tl.Inputs(strcmp({tl.Inputs.name}, 'galvoX')).measurement = 'volts';
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:unknownMeasurement');
        end

        function initRejectsSharedChannelAmongUsedInputs(tc)
            tl = tc.dragontailLike();
            tl.UseInputs{end+1} = 'pump1'; % shares ai1 with galvoX
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:sharedChannel');
        end

        function initRejectsUnknownUseInput(tc)
            tl = tc.dragontailLike();
            tl.UseInputs{end+1} = 'notAnInput';
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:unknownInput');
        end

        function initRejectsDuplicateUseInput(tc)
            tl = tc.dragontailLike();
            tl.UseInputs{end+1} = 'galvoX';
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:duplicateUseInput');
        end

        function initRequiresChronoInputWithChronoOutput(tc)
            tl = tc.dragontailLike();
            tl.Outputs = hw.TLOutputChrono; % errors before the output touches a DAQ
            tl.UseInputs(strcmp(tl.UseInputs, 'chrono')) = [];
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:noChronoInput');
        end

        function initRejectsInputOnOutputChannel(tc)
            tl = tc.dragontailLike();
            chrono = hw.TLOutputChrono;
            chrono.DaqChannelID = 'ctr3';
            tl.Outputs = chrono;
            tl.addInput('licks2', 'ctr3', 'EdgeCount');
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:inputOnOutputChannel');
            % a disabled output does not reserve its channel
            chrono.Enable = false;
            tl.callInit();
            tc.verifyEqual(tl.mainSession().Channels(end).ID, 'ctr3');
        end

        function outputOnOtherDeviceDoesNotClash(tc)
            tl = tc.dragontailLike();
            clock = MockTimelineClock;
            clock.DaqChannelID = 'ctr1'; % same ID as the encoder
            tl.Outputs = clock;
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:inputOnOutputChannel');
            clock.DaqDeviceID = 'Dev2'; % enabled, but on another device
            tl.callInit();
            tc.verifyEqual(tl.mainSession().Channels(2).ID, 'ctr1');
        end

        %% Numeric channel IDs (the DAQ accepts 1 for 'ai1' or 'ctr1')
        function initAcceptsNumericChannelIDs(tc)
            tl = TimelineTestable();
            tl.addInput('numericAnalog', 1, 'Voltage');
            tl.addInput('numericCounter', 1, 'EdgeCount'); % ctr1, not ai1
            tl.callInit();
            ch = tl.mainSession().Channels;
            tc.verifyEqual({ch.ID}, {'ai0', 1, 1});
            tc.verifyEqual({ch.Kind}, {'analog', 'analog', 'counter'});
        end

        function initRejectsNumericAndTextOnSameChannel(tc)
            tl = TimelineTestable();
            tl.addInput('numericAnalog', 1, 'Voltage');
            tl.addInput('textAnalog', 'AI1', 'Voltage');
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:sharedChannel');
            tl.UseInputs = {'chrono', 'numericAnalog'};
            tl.addInput('numericChrono', 0, 'Voltage'); % ai0 is chrono's
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:sharedChannel');
        end

        function initRejectsInputOnNumericOutputChannel(tc)
            tl = tc.dragontailLike(); % lickDetector is on ctr2
            clock = MockTimelineClock;
            clock.DaqChannelID = 2;
            tl.Outputs = clock;
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:inputOnOutputChannel');
            clock.DaqChannelID = 6; % ctr6: no clash with photodiode on ai6
            tl.callInit();
        end

        function initRejectsChannelIDNamingSeveralChannels(tc)
            tl = tc.dragontailLike();
            tl.ChannelsPerAdd = 2;
            tc.verifyError(@() tl.callInit(), 'Rigbox:hw:Timeline:channelCount');
        end

        function initClearsStaleArrayColumns(tc)
            tl = tc.dragontailLike();
            tl.callInit();
            tl.UseInputs(strcmp(tl.UseInputs, 'rotaryEncoder')) = []; % as expServer does
            tl.callInit();
            tc.verifyEqual(tl.Inputs(strcmp({tl.Inputs.name}, 'rotaryEncoder')).arrayColumn, -1);
            tc.verifyEqual(tl.Inputs(strcmp({tl.Inputs.name}, 'galvoX')).arrayColumn, 2);
        end
    end
end
