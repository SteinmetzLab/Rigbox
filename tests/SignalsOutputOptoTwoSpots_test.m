classdef SignalsOutputOptoTwoSpots_test < matlab.unittest.TestCase
    % Tests hw.SignalsOutputOptoTwoSpots without hardware: init() is never
    % called, and a MockDaqSession records what command() would send to the DAQ.

    properties (Constant)
        % Calibration values from the share (as in bakerLaserGUI's
        % TestSignalsConsistency), so conversions run on realistic numbers.
        MMPERV_X       = 1.1111111111111112
        MMPERV_Y       = -1.075268817204301
        BREGMAOFFSET_X = -0.9754170966834995
        BREGMAOFFSET_Y = 0.8580077028529671
        SLOPE_638      = 1.6585965743948425
        INTERCEPT_638  = -0.11019135906855061
        RATE = 100000
    end

    methods (TestClassSetup)
        function addMock(tc)
            here = fileparts(mfilename('fullpath'));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(here, 'fixtures', 'optoTwoSpots')));
        end
    end

    methods (Access = private)
        function obj = makeObj(tc, varargin)
            obj = hw.SignalsOutputOptoTwoSpots638('test', 'Dev3');
            obj.VmWSlope = tc.SLOPE_638;
            obj.VmWIntercept = tc.INTERCEPT_638;
            obj.mmPerV_X = tc.MMPERV_X;
            obj.mmPerV_Y = tc.MMPERV_Y;
            obj.bregmaOffset_X = tc.BREGMAOFFSET_X;
            obj.bregmaOffset_Y = tc.BREGMAOFFSET_Y;
            obj.s = MockDaqSession();
        end

        function [laser, gx, gy, args] = gen(tc, varargin)
            % Waveforms in mm for laser amplitude 1, from name-value overrides.
            obj = tc.makeObj();
            v = [{'amplitude', 3, 'galvoX1', 1.5, 'galvoY1', 1, ...
                'galvoX2', -2.5, 'galvoY2', -3}, varargin];
            args = obj.parseTwoSpotArgs(v);
            [laser, gx, gy] = obj.genTwoSpotWaveforms(1, args);
        end
    end

    methods (Test)
        function classesResolve(tc)
            tc.verifyTrue(isa(hw.SignalsOutputOptoTwoSpots638('a', 'Dev3'), 'hw.SignalsOutputOpto'));
            o594 = hw.SignalsOutputOptoTwoSpots594('b', 'Dev3');
            tc.verifyEqual(o594.laserAOChannel, 'ao3');
            tc.verifyEqual(o594.laserCalibFile, 'laserModCalib594.mat');
            o638 = hw.SignalsOutputOptoTwoSpots638('c', 'Dev3');
            tc.verifyEqual(o638.laserAOChannel, 'ao0');
            tc.verifyEqual(o638.laserCalibFile, 'laserModCalib638.mat');
            % Same channels and calibration files as the single-spot classes.
            tc.verifyEqual(o638.laserAOChannel, hw.SignalsOutputOpto638.laserAOChannel);
            tc.verifyEqual(o594.laserAOChannel, hw.SignalsOutputOpto594.laserAOChannel);
            tc.verifyEqual(o638.laserCalibFile, hw.SignalsOutputOpto638.laserCalibFile);
            tc.verifyEqual(o594.laserCalibFile, hw.SignalsOutputOpto594.laserCalibFile);
        end

        function lengthAndCycleCount(tc)
            [laser, gx, gy] = tc.gen('delay', 0.3, 'duration', 0.3, 'endDelay', 0.05);
            n = round((0.3 + 0.3 + 0.05) * tc.RATE);
            tc.verifyEqual(numel(laser), n);
            tc.verifyEqual(numel(gx), n);
            tc.verifyEqual(numel(gy), n);
            on = find(diff([0; laser > 0]) == 1);
            tc.verifyEqual(numel(on), 2 * 12);  % 0.3 s * 40 Hz cycles, two pulses each
        end

        function pulseTimingAndWidth(tc)
            [laser, ~, ~] = tc.gen('delay', 0.3, 'duration', 0.1);
            on  = find(diff([0; laser > 0]) == 1);
            off = find(diff([laser > 0; 0]) == -1);
            % First pulse at exactly `delay`; t = (index - 1) / rate.
            tc.verifyEqual(on(1), 0.3 * tc.RATE + 1);
            % Pulses every half cycle (12.5 ms at 40 Hz), each 5 ms long.
            tc.verifyEqual(unique(diff(on)), 1250);
            tc.verifyEqual(unique(off - on + 1), 500);
            % Square pulses at the full amplitude by default.
            tc.verifyEqual(unique(laser(laser > 0)), 1);
        end

        function laserOnlyAtStillSpots(tc)
            % While the laser is on, the galvo sits exactly on a spot, and
            % pulses alternate spot 1, spot 2, spot 1, ...
            [laser, gx, gy] = tc.gen('duration', 0.2);
            on  = find(diff([0; laser > 0]) == 1);
            off = find(diff([laser > 0; 0]) == -1);
            spots = [1.5 1; -2.5 -3];
            for k = 1:numel(on)
                idx = on(k):off(k);
                want = spots(2 - mod(k, 2), :);
                tc.verifyEqual(gx(idx), repmat(want(1), numel(idx), 1));
                tc.verifyEqual(gy(idx), repmat(want(2), numel(idx), 1));
            end
            % The galvo has sat still at the spot for the settle time (1250 -
            % 500 - 600 = 150 samples) before each pulse, and is still 1 sample
            % after it.
            for k = 1:numel(on)
                idx = on(k) - 150:on(k);
                tc.verifyEqual(gx(idx), repmat(gx(on(k)), numel(idx), 1));
                tc.verifyEqual(gy(idx), repmat(gy(on(k)), numel(idx), 1));
            end
            % The move's last sample is already at the spot, so the galvo is
            % still 151 samples before each pulse but still moving at 152
            % (except before the first pulse, which follows `delay`).
            tc.verifyTrue(all(gx(on(2:end) - 152) ~= gx(on(2:end))));
            % The move starts on the sample after each pulse, with the laser off.
            tc.verifyTrue(all(gx(off + 1) ~= gx(off)));
            tc.verifyEqual(laser(off + 1), zeros(size(off)));
            % Over the whole command: wherever either galvo is moving, the laser is off.
            moving = [false; diff(gx) ~= 0 | diff(gy) ~= 0];
            tc.verifyEqual(nnz(laser(moving)), 0);
        end

        function galvoContinuousFromAndToBregma(tc)
            [~, gx, gy] = tc.gen();
            % First sample: one step of the 200-sample raised cosine, not a jump.
            tc.verifyEqual(gx(1), 1.5 * (1 - cos(pi / 200)) / 2, 'AbsTol', 1e-15);
            tc.verifyEqual(gy(1), 1.0 * (1 - cos(pi / 200)) / 2, 'AbsTol', 1e-15);
            tc.verifyEqual(gx(end), 0);
            tc.verifyEqual(gy(end), 0);
            % Largest step: the 6 ms raised-cosine move of 4 mm in x, peak
            % slope pi/2 * 4 mm / 600 samples ~ 0.0105 mm per sample; the 2 ms
            % bregma ramps: pi/2 * 1.5 / 200 ~ 0.0118.
            tc.verifyLessThan(max(abs(diff(gx))), 0.012);
            tc.verifyLessThan(max(abs(diff(gy))), 0.012);
            % Galvo at spot 1 before the first pulse and after the last.
            tc.verifyEqual(gx(0.3 * tc.RATE), 1.5);
            tc.verifyEqual(gx(end - 0.05 * tc.RATE + 1), 1.5);
        end

        function moveIsRaisedCosine(tc)
            [laser, gx, ~] = tc.gen();
            % The move to spot 2 starts right after the first pulse ends.
            off1 = find(diff([laser > 0; 0]) == -1, 1);
            m = gx(off1 + (1:600));
            want = 1.5 + (1 - cos(pi * (1:600)' / 600)) / 2 * (-4);
            tc.verifyEqual(m, want, 'AbsTol', 1e-12);
        end

        function durationMustBeWholeCycles(tc)
            obj = tc.makeObj();
            base = {'amplitude', 3, 'galvoX1', 0, 'galvoY1', 0, 'galvoX2', 1, 'galvoY2', 1};
            tc.verifyError(@() obj.command([base, {'duration', 0.31}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyError(@() obj.command([base, {'duration', 0.001}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyError(@() obj.command([base, {'cycleFreq', 30}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyEqual(obj.s.started, 0);
            [laser, ~, ~] = tc.gen('duration', 0.5);
            tc.verifyEqual(sum(diff([0; laser > 0]) == 1), 40);
        end

        function zeroDurationIsDark(tc)
            % A sham: no light at all, the galvo still goes to spot 1 and back.
            [laser, gx, ~] = tc.gen('duration', 0);
            tc.verifyEqual(nnz(laser), 0);
            tc.verifyEqual(numel(laser), round(0.35 * tc.RATE));
            tc.verifyEqual(max(gx), 1.5);
            tc.verifyEqual(gx(end), 0);
        end

        function firstPulseGetsSettle(tc)
            % The first pulse waits at spot 1 at least as long as later pulses
            % do (150 samples), however delay and galvoRampDur are set.
            obj = tc.makeObj();
            base = {'amplitude', 3, 'galvoX1', 0, 'galvoY1', 0, 'galvoX2', 1, 'galvoY2', 1};
            tc.verifyError(@() obj.command([base, {'delay', 0.002}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyError(@() obj.command([base, {'delay', 0, 'galvoRampDur', 0}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyEqual(obj.s.started, 0);
            [laser, gx, ~] = tc.gen('delay', 0.0035);  % exactly 200 + 150 samples
            on1 = find(laser > 0, 1);
            tc.verifyEqual(on1, 351);
            tc.verifyEqual(gx(200:on1), repmat(1.5, on1 - 199, 1));
            tc.verifyLessThan(gx(199), 1.5);
        end

        function laserRampsInsidePulse(tc)
            [laser, ~, ~] = tc.gen('laserRampDur', 0.001, 'duration', 0.025);
            on = find(diff([0; laser > 0]) == 1);
            p = laser(on(1):on(1) + 499);
            tc.verifyEqual(p(100), 1, 'AbsTol', 1e-12);
            tc.verifyEqual(p(401), 1, 'AbsTol', 1e-12);
            tc.verifyEqual(p, flipud(p), 'AbsTol', 1e-12);
            tc.verifyEqual(p(50), 0.5, 'AbsTol', 1e-12);
            % Energy: pulseDur - laserRampDur at peak (sum of a raised cosine
            % over n samples = n/2 + 1/2 including its end at 1).
            tc.verifyEqual(sum(p), 500 - 100 + 1, 'AbsTol', 1e-9);
        end

        function commandConvertsAndQueues(tc)
            obj = tc.makeObj();
            obj.command(struct('amplitude', 3, 'galvoX1', 1.5, 'galvoY1', 1, ...
                'galvoX2', -2.5, 'galvoY2', -3));
            q = obj.s.queued;
            tc.verifyEqual(obj.s.started, 1);
            tc.verifySize(q, [round(0.65 * tc.RATE), 3]);
            wantV = (3 - tc.INTERCEPT_638) / tc.SLOPE_638;
            tc.verifyEqual(max(q(:, 1)), wantV, 'AbsTol', 1e-12);
            % Galvo volts: the base class's conversion of the mm waveforms.
            [~, gx, gy] = tc.gen();
            tc.verifyEqual(q(:, 2), gx / tc.MMPERV_X + tc.BREGMAOFFSET_X, 'AbsTol', 1e-12);
            tc.verifyEqual(q(:, 3), gy / tc.MMPERV_Y + tc.BREGMAOFFSET_Y, 'AbsTol', 1e-12);
            % Same conversion as the single-spot class at a spot.
            single = hw.SignalsOutputOpto638('ref', 'Dev3');
            single.mmPerV_X = tc.MMPERV_X; single.bregmaOffset_X = tc.BREGMAOFFSET_X;
            single.mmPerV_Y = tc.MMPERV_Y; single.bregmaOffset_Y = tc.BREGMAOFFSET_Y;
            [vx, vy] = single.calib_GalvoPos(-2.5, -3);
            tc.verifyTrue(any(abs(q(:, 2) - vx) < 1e-12 & abs(q(:, 3) - vy) < 1e-12));
        end

        function amplitudeMinusOneIsFiveVolts(tc)
            obj = tc.makeObj();
            obj.command({'amplitude', -1, 'galvoX1', 0, 'galvoY1', 0, 'galvoX2', 1, 'galvoY2', 1});
            tc.verifyEqual(max(obj.s.queued(:, 1)), 5);
        end

        function zeroAmplitudeMatchesSingleSpotConvention(tc)
            % 0 mW sends the fit's zero crossing, like hw.SignalsOutputOpto.
            obj = tc.makeObj();
            obj.command({'amplitude', 0, 'galvoX1', 0, 'galvoY1', 0, 'galvoX2', 1, 'galvoY2', 1});
            tc.verifyEqual(max(obj.s.queued(:, 1)), -tc.INTERCEPT_638 / tc.SLOPE_638, 'AbsTol', 1e-12);
        end

        function caseInsensitiveNames(tc)
            obj = tc.makeObj();
            obj.command({'AMPLITUDE', 3, 'galvox1', 1.5, 'GalvoY1', 1, 'galvoX2', -2.5, 'galvoY2', -3});
            tc.verifyEqual(obj.s.started, 1);
        end

        function rejectsBadInput(tc)
            obj = tc.makeObj();
            base = {'amplitude', 3, 'galvoX1', 0, 'galvoY1', 0, 'galvoX2', 1, 'galvoY2', 1};
            tc.verifyError(@() obj.command(base(1:8)), 'SignalsOutputOptoTwoSpots:command:missingArg');
            tc.verifyError(@() obj.command([base, {'galvoX', 1}]), 'SignalsOutputOptoTwoSpots:command:unknownArg');
            tc.verifyError(@() obj.command([base, {'duration'}]), 'SignalsOutputOptoTwoSpots:command:badPairs');
            tc.verifyError(@() obj.command([1 2 3]), 'SignalsOutputOptoTwoSpots:command:badInput');
            tc.verifyError(@() obj.command([base, {'galvoX1', [1 2]}]), 'SignalsOutputOptoTwoSpots:command:badValue');
            tc.verifyError(@() obj.command([base, {'galvoX1', NaN}]), 'SignalsOutputOptoTwoSpots:command:badValue');
            tc.verifyError(@() obj.command([base, {'delay', -1}]), 'SignalsOutputOptoTwoSpots:command:badValue');
            tc.verifyError(@() obj.command([base, {'amplitude', -2}]), 'SignalsOutputOptoTwoSpots:command:badValue');
            tc.verifyError(@() obj.command([base, {'cycleFreq', 0}]), 'SignalsOutputOptoTwoSpots:command:badValue');
            tc.verifyEqual(obj.s.started, 0);  % nothing reached the DAQ
        end

        function rejectsImpossibleTiming(tc)
            obj = tc.makeObj();
            base = {'amplitude', 3, 'galvoX1', 0, 'galvoY1', 0, 'galvoX2', 1, 'galvoY2', 1};
            tc.verifyError(@() obj.command([base, {'cycleFreq', 100}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyError(@() obj.command([base, {'laserRampDur', 0.003}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyError(@() obj.command([base, {'delay', 0.001}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyError(@() obj.command([base, {'endDelay', 0.001}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyError(@() obj.command([base, {'pulseDur', 0}]), 'SignalsOutputOptoTwoSpots:timing');
            tc.verifyError(@() obj.command([base, {'amplitude', 50}]), 'SignalsOutputOptoTwoSpots:command:tooBright');
            tc.verifyEqual(obj.s.started, 0);
        end

        function matchesLegacyCycle(tc)
            % Per cycle, the same pulses as hw.SignalsOutputGalvoOptoTwoSpots:
            % 500 samples at each spot, at peak amplitude, galvo still.
            legacy = hw.SignalsOutputGalvoOptoTwoSpots('legacy', 'Dev3');
            [lLas, lgx, lgy] = legacy.genWaveforms(1, 0.3, [1.5 -2.5], [1 -3], 0);
            [nLas, ngx, ngy] = tc.gen('duration', 0.3);
            tc.verifyEqual(sum(lLas), sum(nLas));  % same total on-time at peak
            tc.verifyEqual(sum(lLas > 0 & lgx == 1.5 & lgy == 1), sum(nLas > 0 & ngx == 1.5 & ngy == 1));
            tc.verifyEqual(sum(lLas > 0 & lgx == -2.5 & lgy == -3), sum(nLas > 0 & ngx == -2.5 & ngy == -3));
            % Legacy cycle is 2502 samples (25.02 ms); this one is exactly 2500.
            lOn = find(diff([0; lLas > 0]) == 1);
            nOn = find(diff([0; nLas > 0]) == 1);
            tc.verifyEqual(unique(diff(lOn(1:2:end))), 2502);
            tc.verifyEqual(unique(diff(nOn(1:2:end))), 2500);
        end

        function singleSpotClassUntouched(tc)
            % The single-spot class must not have gained any two-spot behavior.
            tc.verifyError(@() hw.SignalsOutputOpto638('x', 'Dev3').command( ...
                struct('amplitude', 1, 'galvoX1', 0, 'galvoY1', 0)), ...
                'SignalsOutputOpto:command:unknownArg');
        end
    end
end
