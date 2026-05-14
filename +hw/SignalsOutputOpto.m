classdef SignalsOutputOpto < hw.SignalsOutput
  %SIGNALSOUTPUTOPTO  Base class for galvo-steered optogenetic laser stimulation.
  %
  % Subclasses must set:
  %   laserAOChannel  - DAQ analog output channel for laser modulation (e.g. 'ao0')
  %   laserCalibFile  - filename of laser power calibration .mat (in calibDir/laserModCalib/)
  %
  % command() accepts a struct or cell array of name-value pairs.
  %
  %   Required:
  %     amplitude - (mW) laser power; use -1 to send 5V directly (bypasses calibration)
  %     galvoX - (mm from bregma) target position, mediolateral; negative = left
  %     galvoY - (mm from bregma) target position, anteroposterior; negative = posterior
  %
  %   Optional:
  %     duration - (s, default 0.1) laser pulse duration
  %     delay - (s, default 0.3) delay between galvo move and laser on
  %     endDelay - (s, default 0.05) delay between laser off and galvo move
  %     doSineWave - (default 0) enable 40 Hz raised cosine modulation.
  %         note that the amplitude will reach twice what you command (so
  %         that you get the desired amplitude on average)
  %     laserRampDur - (s, default 0.002) laser onset/offset ramp duration
  %     galvoRampDur - (s, default 0.002) galvo onset/offset ramp duration
  %
  % See also HW.SignalsOutput, HW.SIGNALSOUTPUTOPTO638, HW.SIGNALSOUTPUTOPTO594
  %
  % 2026 AL

  properties
    devID = 'Dev3';
    s = []; % daq session
    rate = 100000;
    mmPerV_X = 1;
    mmPerV_Y = 1;
    VmWSlope = 1;
    VmWIntercept = 0;
    bregmaOffset_X = 0;
    bregmaOffset_Y = 0;
    calibDir = '\\sahale.biostr.washington.edu\data\Code\Rigging\optoGalvo\calib\';
  end

  properties (Abstract, Constant)
    laserAOChannel   % e.g. 'ao0'
    laserCalibFile   % e.g. 'laserModCalib638.mat'
  end

  methods
    function obj = SignalsOutputOpto(name, devID)
        obj.Name = name;
        obj.devID = devID;
    end

    function init(obj)
        newS = daq.createSession('ni');
        newS.addAnalogOutputChannel(obj.devID, obj.laserAOChannel, 'Voltage');
        newS.addAnalogOutputChannel(obj.devID, 'ao1', 'Voltage');  % galvo X
        newS.addAnalogOutputChannel(obj.devID, 'ao2', 'Voltage');  % galvo Y
        newS.Rate = obj.rate;
        obj.s = newS;

        % laser power calibration (per-subclass file)
        mWperVfile = fullfile(obj.calibDir, 'laserModCalib', obj.laserCalibFile);
        if isfile(mWperVfile)
            xx = load(mWperVfile);
            obj.VmWSlope = xx.calibSlope;
            obj.VmWIntercept = xx.calibIntercept;
        end

        % galvo calibrations (shared)
        mmPerV_Xfile = fullfile(obj.calibDir, 'mmPerV_X.mat');
        if isfile(mmPerV_Xfile)
            xx = load(mmPerV_Xfile);
            obj.mmPerV_X = xx.mmPerV_X;
        end
        mmPerV_Yfile = fullfile(obj.calibDir, 'mmPerV_Y.mat');
        if isfile(mmPerV_Yfile)
            xx = load(mmPerV_Yfile);
            obj.mmPerV_Y = xx.mmPerV_Y;
        end
        bregmaOffset_Xfile = fullfile(obj.calibDir, 'bregmaOffset_X.mat');
        if isfile(bregmaOffset_Xfile)
            xx = load(bregmaOffset_Xfile);
            obj.bregmaOffset_X = xx.bregmaOffset_X;
        end
        bregmaOffset_Yfile = fullfile(obj.calibDir, 'bregmaOffset_Y.mat');
        if isfile(bregmaOffset_Yfile)
            xx = load(bregmaOffset_Yfile);
            obj.bregmaOffset_Y = xx.bregmaOffset_Y;
        end
    end

    function command(obj, v)
        % --- defaults (empty = required) ---
        args = struct( ...
            'amplitude',  [], ...   % required
            'galvoX',     [], ...   % required
            'galvoY',     [], ...   % required
            'duration',   0.1, ...
            'delay',      0.3, ...
            'doSineWave',   0, ...
            'endDelay',     0.05, ...
            'laserRampDur', 0.002, ...
            'galvoRampDur', 0.002);

        validNames = fieldnames(args);
        required   = {'amplitude','galvoX','galvoY'};

        % --- normalize input to a struct ---
        if isstruct(v)
            inStruct = v;
        elseif iscell(v)
            if mod(numel(v), 2) ~= 0
                error('SignalsOutputOpto:command:badPairs', ...
                    'Name-value cell must have an even number of elements.');
            end
            inStruct = struct();
            for k = 1:2:numel(v)
                if ~(ischar(v{k}) || (isstring(v{k}) && isscalar(v{k})))
                    error('SignalsOutputOpto:command:badName', ...
                        'Argument names must be strings/chars.');
                end
                inStruct.(char(v{k})) = v{k+1};
            end
        else
            error('SignalsOutputOpto:command:badInput', ...
                'command() expects a struct or cell of name-value pairs. Got %s.', class(v));
        end

        % --- merge into args, reject unknown names ---
        fn = fieldnames(inStruct);
        for k = 1:numel(fn)
            idx = find(strcmpi(fn{k}, validNames), 1);
            if isempty(idx)
                error('SignalsOutputOpto:command:unknownArg', ...
                    'Unknown argument ''%s''. Valid: %s.', fn{k}, strjoin(validNames, ', '));
            end
            args.(validNames{idx}) = inStruct.(fn{k});
        end

        % --- enforce required ---
        for k = 1:numel(required)
            if isempty(args.(required{k}))
                error('SignalsOutputOpto:command:missingArg', ...
                    'Required argument ''%s'' not provided.', required{k});
            end
        end

        % --- unpack ---
        laserAmp       = args.amplitude;
        galvoXPos      = args.galvoX;
        galvoYPos      = args.galvoY;
        laserDurS      = args.duration;
        laserDelay     = args.delay;
        doSineWave     = args.doSineWave;
        laserEndDelayS = args.endDelay;
        laserRampDur   = args.laserRampDur;
        galvoRampDur   = args.galvoRampDur;

        s    = obj.s;
        rate = obj.rate;

        trialTimeS     = laserDelay + laserDurS + laserEndDelayS;
        delayTimeSamps = max(1, round(laserDelay * rate));  % min 1 sample to avoid 0-index
        trialTimeSamps = round(trialTimeS * rate);

        if laserAmp == -1
            laserAmp_V = 5 / (1 + doSineWave);  % 5V DC, or 2.5V so sine peaks at 5V
            maxMW = 5 * obj.VmWSlope + obj.VmWIntercept;
            fprintf(1, 'Sending max (%.1f mW) %3.2fs. Galvo X,Y: %4.3f, %4.3f. SineWave %d.\n', ...
                maxMW, laserDurS, galvoXPos, galvoYPos, doSineWave);
        else
            laserAmp_V = (laserAmp - obj.VmWIntercept) / obj.VmWSlope;
            fprintf(1, 'Laser %.1f mW %3.2fs. Galvo X,Y: %4.3f, %4.3f. SineWave %d.\n', ...
                laserAmp, laserDurS, galvoXPos, galvoYPos, doSineWave);
        end
        laser  = obj.genLaser(laserAmp_V, laserDurS, trialTimeSamps, delayTimeSamps, doSineWave, laserRampDur);
        galvoX = obj.genGalvo(galvoXPos, trialTimeSamps, galvoRampDur);
        galvoY = obj.genGalvo(galvoYPos, trialTimeSamps, galvoRampDur);

        [galvoX, galvoY] = obj.calib_GalvoPos(galvoX, galvoY);

        s.queueOutputData([laser galvoX galvoY]);
        s.startBackground();
    end

    function delete(obj)
        if ~isempty(obj.s)
            obj.s.stop();
            delete(obj.s);
        end
    end

    function waveform = genLaser(obj, laserAmp, laserDur, trialTimeSamps, delayTimeSamps, doSineWave, laserRampDur)
        rate = obj.rate;
        laserDurSamps = round(laserDur * rate);
        waveform = zeros(trialTimeSamps, 1);
        if ~doSineWave
            waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = laserAmp;
            thisRamp = obj.genRamp(laserRampDur, laserAmp);
            waveform(delayTimeSamps:delayTimeSamps+numel(thisRamp)-1) = thisRamp;
            waveform(delayTimeSamps+laserDurSamps-numel(thisRamp)+1:delayTimeSamps+laserDurSamps) = fliplr(thisRamp);
        else
            swFreq = 40;
            laserDur = floor(laserDur/0.025)*0.025;
            laserDurSamps = round(laserDur * rate);
            t = (1:laserDurSamps+1)/rate;
            raisedcos = laserAmp*(1+cos(pi+swFreq*2*pi*t));
            if laserDur >= 0.4
                troughs = 0:1/swFreq:t(end);
                nAttenPeaks = 4;
                attFactor = cumprod(ones(nAttenPeaks, 1)*0.75);
                attFactor = flip(attFactor);
                for i = nAttenPeaks:-1:1
                    [~, peakIdx] = min(abs(t-troughs(end-i)));
                    raisedcos(peakIdx:end) = raisedcos(peakIdx:end)*attFactor(i);
                end
            end
            waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = raisedcos;
        end
    end

    function waveform = genGalvo(obj, galvoPos, trialTimeSamps, galvoRampDur)
        thisRamp = obj.genRamp(galvoRampDur, galvoPos);
        waveform = zeros(trialTimeSamps, 1) + galvoPos;
        waveform(1:numel(thisRamp)) = thisRamp;
        waveform(end-numel(thisRamp)+1:end) = fliplr(thisRamp);
    end

    function ramp = genRamp(obj, duration, amp)
        rate = obj.rate;
        t = 0:1/rate:duration;
        f = 1/(duration*2);
        ramp = amp*0.5*(1-cos(t*(2*pi*f)));
    end

    function [galvoX, galvoY] = calib_GalvoPos(obj, galvoX, galvoY)
        galvoX = galvoX/obj.mmPerV_X + obj.bregmaOffset_X;
        galvoY = galvoY/obj.mmPerV_Y + obj.bregmaOffset_Y;
    end
  end

end
