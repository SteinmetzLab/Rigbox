classdef SignalsOutputOptoTwoSpots < hw.SignalsOutputOpto
  %SIGNALSOUTPUTOPTOTWOSPOTS  Two spots stimulated pseudo-simultaneously by scanning.
  %
  % The galvos alternate between two spots inside each cycle of cycleFreq
  % (default 40 Hz). Each spot receives one laser pulse of pulseDur per cycle,
  % and the galvos move between spots with the laser off. The spot 2 pulse
  % starts half a cycle after the spot 1 pulse. Each half cycle is: pulse,
  % move to the other spot right away, then settle there with the laser off
  % for the rest of the half cycle (half cycle - pulseDur - moveDur; 1.5 ms
  % at the defaults), so the mirrors have caught up before the next pulse.
  %
  %   one cycle (40 Hz defaults, 25 ms):
  %   laser  |##|____________|##|____________|
  %   galvo   s1 move  settle s2 move  settle s1
  %           0 ms          12.5 ms          25 ms
  %
  % Laser power, galvo calibrations, and the DAQ session come from
  % hw.SignalsOutputOpto.init, so the conversions match single-spot
  % experiments exactly. Subclasses set laserAOChannel and laserCalibFile.
  %
  % command() accepts a struct or cell array of name-value pairs.
  %
  %   Required:
  %     amplitude - (mW) PEAK laser power during each pulse; use -1 to send
  %         5 V directly (bypasses calibration). Each spot's time-averaged
  %         power is amplitude * pulseDur * cycleFreq (20% at the defaults).
  %     galvoX1, galvoY1 - (mm from bregma) spot 1, stimulated first
  %     galvoX2, galvoY2 - (mm from bregma) spot 2
  %         X is mediolateral (negative = left), Y is anteroposterior
  %         (negative = posterior), as in hw.SignalsOutputOpto.
  %
  %   Optional:
  %     duration - (s, default 0.3) stimulation time; must be a whole
  %         number of cycles (0.3 s = 12 cycles at 40 Hz), or the command
  %         errors rather than deliver a duration other than the one the
  %         Block records. 0 gives no pulses (a sham): the galvo still
  %         visits spot 1.
  %     delay - (s, default 0.3) from the start of the command to the first
  %         pulse, as in hw.SignalsOutputOpto. The galvo arrives at spot 1
  %         after galvoRampDur, so it sits there for delay - galvoRampDur;
  %         that must be at least the settle time before every other pulse.
  %     endDelay - (s, default 0.05) from the end of the last cycle to the
  %         end of the command; the galvo returns to bregma during its last
  %         galvoRampDur, so it must be at least galvoRampDur
  %     cycleFreq - (Hz, default 40) scan cycles per second; half a cycle
  %         must be a whole number of samples at the 100 kHz rate
  %     pulseDur - (s, default 0.005) laser on time at each spot per cycle
  %     moveDur - (s, default 0.006) raised-cosine galvo move between spots
  %     laserRampDur - (s, default 0) raised-cosine ramp at each pulse edge,
  %         inside pulseDur. 0 gives square pulses, as in the legacy
  %         hw.SignalsOutputGalvoOptoTwoSpots_legacy. A ramp lowers each pulse's
  %         energy: a ramp of r on both edges delivers (pulseDur - r) at peak
  %         power instead of pulseDur.
  %     galvoRampDur - (s, default 0.002) galvo ramp from bregma to spot 1
  %         at the start and from spot 1 back to bregma at the end
  %
  % Differences from the legacy hw.SignalsOutputGalvoOptoTwoSpots_legacy:
  %   - Spot 1 is pulsed first. The legacy class began moving at once and
  %     pulsed its second spot (galvoPos2x, galvoPos2y) first, 6 ms in.
  %   - The galvo reaches spot 1 and waits before the first pulse.
  %   - Each pulse follows a settle at its spot. The legacy pulse began the
  %     moment the move command ended, and the slack came after it.
  %   - The cycle is exactly rate/cycleFreq samples. The legacy cycle was 2
  %     samples longer: 25.02 ms, 39.97 Hz.
  %   - The galvo returns to bregma at the end, and the arguments are named.
  %
  % See also HW.SIGNALSOUTPUTOPTO, HW.SIGNALSOUTPUTOPTOTWOSPOTS638,
  % HW.SIGNALSOUTPUTOPTOTWOSPOTS594, HW.SIGNALSOUTPUTGALVOOPTOTWOSPOTS
  %
  % 2026 AL

  methods
    function obj = SignalsOutputOptoTwoSpots(name, devID)
        obj@hw.SignalsOutputOpto(name, devID);
    end

    function command(obj, v)
        args = obj.parseTwoSpotArgs(v);

        if args.amplitude == -1
            laserAmp_V = 5;
            fprintf(1, 'Two spots, max (%.1f mW peak) %3.2fs. Spot 1 %4.3f, %4.3f; spot 2 %4.3f, %4.3f.\n', ...
                5 * obj.VmWSlope + obj.VmWIntercept, args.duration, ...
                args.galvoX1, args.galvoY1, args.galvoX2, args.galvoY2);
        else
            laserAmp_V = (args.amplitude - obj.VmWIntercept) / obj.VmWSlope;
            fprintf(1, 'Two spots, %.1f mW peak %3.2fs. Spot 1 %4.3f, %4.3f; spot 2 %4.3f, %4.3f.\n', ...
                args.amplitude, args.duration, ...
                args.galvoX1, args.galvoY1, args.galvoX2, args.galvoY2);
        end
        if laserAmp_V > 5
            error('SignalsOutputOptoTwoSpots:command:tooBright', ...
                '%.2f mW needs %.2f V, above the 5 V modulation range.', ...
                args.amplitude, laserAmp_V);
        end

        [laser, galvoX, galvoY] = obj.genTwoSpotWaveforms(laserAmp_V, args);
        [galvoX, galvoY] = obj.calib_GalvoPos(galvoX, galvoY);

        obj.s.queueOutputData([laser galvoX galvoY]);
        obj.s.startBackground();
    end

    function [laser, galvoX, galvoY] = genTwoSpotWaveforms(obj, laserAmp, args)
        % Laser in the units of laserAmp (V when called from command);
        % galvos in mm from bregma, before calib_GalvoPos. args is the
        % struct from parseTwoSpotArgs.
        rate = obj.rate;
        halfSamps   = round(rate / (2 * args.cycleFreq));
        pulseSamps  = round(args.pulseDur * rate);
        moveSamps   = round(args.moveDur * rate);
        lRampSamps  = round(args.laserRampDur * rate);
        gRampSamps  = round(args.galvoRampDur * rate);
        delaySamps  = round(args.delay * rate);
        endSamps    = round(args.endDelay * rate);
        nCycles     = round(args.duration * args.cycleFreq);

        if abs(rate / (2 * args.cycleFreq) - halfSamps) > 1e-9
            error('SignalsOutputOptoTwoSpots:timing', ...
                'Half a cycle at %g Hz is not a whole number of samples at %g Hz.', ...
                args.cycleFreq, rate);
        end
        if abs(args.duration * args.cycleFreq - nCycles) > 1e-6
            error('SignalsOutputOptoTwoSpots:timing', ...
                'duration %g s is not a whole number of %g Hz cycles (%g s each).', ...
                args.duration, args.cycleFreq, 1 / args.cycleFreq);
        end

        if pulseSamps < 1 || moveSamps < 1
            error('SignalsOutputOptoTwoSpots:timing', ...
                'pulseDur and moveDur must each be at least one sample (%g s).', 1/rate);
        end
        settleSamps = halfSamps - pulseSamps - moveSamps;
        if settleSamps < 0
            error('SignalsOutputOptoTwoSpots:timing', ...
                'pulseDur + moveDur (%g s) exceeds half a cycle (%g s at %g Hz).', ...
                args.pulseDur + args.moveDur, halfSamps / rate, args.cycleFreq);
        end
        if 2 * lRampSamps > pulseSamps
            error('SignalsOutputOptoTwoSpots:timing', ...
                'Two laserRampDur (%g s) do not fit in pulseDur (%g s).', ...
                args.laserRampDur, args.pulseDur);
        end
        if delaySamps - gRampSamps < settleSamps
            error('SignalsOutputOptoTwoSpots:timing', ...
                'delay (%g s) must be at least galvoRampDur + the settle time (%g s).', ...
                args.delay, (gRampSamps + settleSamps) / rate);
        end
        if gRampSamps > endSamps
            error('SignalsOutputOptoTwoSpots:timing', ...
                'endDelay (%g s) must be at least galvoRampDur (%g s).', ...
                args.endDelay, args.galvoRampDur);
        end

        % One cycle, starting with the galvo at spot 1. Each half: pulse,
        % move to the other spot, settle there (laser off, galvo still).
        pulse = ones(pulseSamps, 1);
        if lRampSamps > 0
            edge = obj.rampUp(lRampSamps);
            pulse(1:lRampSamps) = edge;
            pulse(end-lRampSamps+1:end) = flipud(edge);
        end
        halfLaser = [pulse; zeros(moveSamps + settleSamps, 1)];
        cycLaser = [halfLaser; halfLaser];

        move = obj.rampUp(moveSamps);  % 0 to 1; last sample exactly 1
        frac = [zeros(pulseSamps, 1); move; ones(settleSamps + pulseSamps, 1); ...
            1 - move; zeros(settleSamps, 1)];  % 0 at spot 1, 1 at spot 2
        cycX = args.galvoX1 + frac * (args.galvoX2 - args.galvoX1);
        cycY = args.galvoY1 + frac * (args.galvoY2 - args.galvoY1);

        % Ramp from bregma to spot 1, wait `delay` from its start, scan, wait
        % `endDelay` at spot 1, ramp back to bregma within that wait.
        gIn = obj.rampUp(gRampSamps);
        preFrac  = [gIn; ones(delaySamps - gRampSamps, 1)];
        postFrac = [ones(endSamps - gRampSamps, 1); 1 - gIn];

        laser  = laserAmp * [zeros(delaySamps, 1); repmat(cycLaser, nCycles, 1); zeros(endSamps, 1)];
        galvoX = [args.galvoX1 * preFrac; repmat(cycX, nCycles, 1); args.galvoX1 * postFrac];
        galvoY = [args.galvoY1 * preFrac; repmat(cycY, nCycles, 1); args.galvoY1 * postFrac];
    end

    function args = parseTwoSpotArgs(~, v)
        % Normalizes a struct or name-value cell to the full argument struct,
        % filling defaults, rejecting unknown names (case-insensitive), and
        % enforcing the required ones.
        args = struct( ...
            'amplitude',    [], ...   % required
            'galvoX1',      [], ...   % required
            'galvoY1',      [], ...   % required
            'galvoX2',      [], ...   % required
            'galvoY2',      [], ...   % required
            'duration',     0.3, ...
            'delay',        0.3, ...
            'endDelay',     0.05, ...
            'cycleFreq',    40, ...
            'pulseDur',     0.005, ...
            'moveDur',      0.006, ...
            'laserRampDur', 0, ...
            'galvoRampDur', 0.002);
        validNames = fieldnames(args);
        required   = {'amplitude', 'galvoX1', 'galvoY1', 'galvoX2', 'galvoY2'};

        if isstruct(v)
            inStruct = v;
        elseif iscell(v)
            if mod(numel(v), 2) ~= 0
                error('SignalsOutputOptoTwoSpots:command:badPairs', ...
                    'Name-value cell must have an even number of elements.');
            end
            inStruct = struct();
            for k = 1:2:numel(v)
                if ~(ischar(v{k}) || (isstring(v{k}) && isscalar(v{k})))
                    error('SignalsOutputOptoTwoSpots:command:badName', ...
                        'Argument names must be strings/chars.');
                end
                inStruct.(char(v{k})) = v{k+1};
            end
        else
            error('SignalsOutputOptoTwoSpots:command:badInput', ...
                'command() expects a struct or cell of name-value pairs. Got %s.', class(v));
        end

        fn = fieldnames(inStruct);
        for k = 1:numel(fn)
            idx = find(strcmpi(fn{k}, validNames), 1);
            if isempty(idx)
                error('SignalsOutputOptoTwoSpots:command:unknownArg', ...
                    'Unknown argument ''%s''. Valid: %s.', fn{k}, strjoin(validNames, ', '));
            end
            args.(validNames{idx}) = inStruct.(fn{k});
        end

        for k = 1:numel(validNames)
            val = args.(validNames{k});
            if ismember(validNames{k}, required) && isempty(val)
                error('SignalsOutputOptoTwoSpots:command:missingArg', ...
                    'Required argument ''%s'' not provided.', validNames{k});
            end
            if ~(isnumeric(val) || islogical(val)) || ~isscalar(val) || ~isfinite(val)
                error('SignalsOutputOptoTwoSpots:command:badValue', ...
                    '''%s'' must be one finite number.', validNames{k});
            end
        end
        nonNeg = {'duration', 'delay', 'endDelay', 'pulseDur', 'moveDur', ...
            'laserRampDur', 'galvoRampDur'};
        for k = 1:numel(nonNeg)
            if args.(nonNeg{k}) < 0
                error('SignalsOutputOptoTwoSpots:command:badValue', ...
                    '''%s'' must not be negative.', nonNeg{k});
            end
        end
        if args.cycleFreq <= 0
            error('SignalsOutputOptoTwoSpots:command:badValue', '''cycleFreq'' must be positive.');
        end
        if args.amplitude < 0 && args.amplitude ~= -1
            error('SignalsOutputOptoTwoSpots:command:badValue', ...
                '''amplitude'' must be 0 or more mW, or -1 for 5 V.');
        end
    end
  end

  methods (Static, Access = protected)
    function r = rampUp(n)
        % n samples of a raised cosine rising from just above 0 to exactly 1.
        if n == 0
            r = zeros(0, 1);
        else
            r = (1 - cos(pi * (1:n)' / n)) / 2;
        end
    end
  end

end
