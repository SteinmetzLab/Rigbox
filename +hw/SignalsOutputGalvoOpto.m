classdef SignalsOutputGalvoOpto < hw.SignalsOutput
  %HW.SignalsOutputArduinoGeneric 
  %
  % See also HW.SignalsOutput
  %
  % Part of Rigbox
  % 2020-11 NS
  
  properties
    devID = 'Dev3';
    s = []; % daq session
    rate = 100000; 
    mmPerV_X = 1; % conversion for galvo position
    mmPerV_Y = 1; 
    VmWSlope = 1; % conversion for laser power
    VmWIntercept = 0; % conversion for laser power
    bregmaOffset_X = 0; % in units of V
    bregmaOffset_Y = 0; 
    calibDir = '\\sahale.biostr.washington.edu\data\Code\Rigging\optoGalvo\calib\';
  end
  
  methods
    function obj = SignalsOutputGalvoOpto(name,devID)
      
        obj.Name = name;        
        obj.devID = devID;
        
    end

    function init(obj)
        newS = daq.createSession('ni');
        newS.addAnalogOutputChannel(obj.devID, 'ao0', 'Voltage');
        newS.addAnalogOutputChannel(obj.devID, 'ao1', 'Voltage');
        newS.addAnalogOutputChannel(obj.devID, 'ao2', 'Voltage');
        newS.Rate = obj.rate;
        obj.s = newS;
        
        % look for calibration factors to load (otherwise keeping defaults)
        mWperVfile = fullfile(obj.calibDir, 'laserModCalib', 'laserModCalib638.mat');
        if isfile(mWperVfile)
            xx = load(mWperVfile);
            obj.VmWSlope = xx.calibSlope;
            obj.VmWIntercept = xx.calibIntercept;
%             mWtoV = @(y) (y-newestCalib.calibIntercept)/newestCalib.calibSlope;
        end
        
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
        
        s = obj.s;
        rate = obj.rate;
        
        % extract the specified parameters
        laserAmp = v(1);
        laserDurS = v(2);
        laserDelay = v(3); 
        galvoXPos = v(4); 
        galvoYPos = v(5); 
        laserFreq = v(6); % sine wave freq: 0 if not a wave
        try
            laserEndDelayS = v(7);
        catch
            laserEndDelayS = 0.05; % ms
        end
        % laserRamp...?
        % galvoRamp...?
        
        fprintf(1, 'Laser on %2.1fV %3.2fS. Galvo X, Y: %4.3f, %4.3f\n. Freq(bool) %2.1f.', ...
            laserAmp, laserDurS, galvoXPos, galvoYPos, laserFreq); 
        
        % set timing parameters for this trial
%         delayTimeS = 0.2+rand*(laserDelay+0.2);

        trialTimeS = laserDelay + laserDurS + laserEndDelayS;

        % convert into NI samples
        delayTimeSamps = round(laserDelay*rate);
        trialTimeSamps = round(trialTimeS*rate);

        % create the waveforms for each component
        laserAmp_V = (laserAmp-obj.VmWIntercept)/obj.VmWSlope; % convert mW input to V
        laser = obj.genLaser(laserAmp_V, laserDurS, trialTimeSamps, delayTimeSamps, laserFreq);
        galvoX = obj.genGalvo(galvoXPos, trialTimeSamps);
        galvoY = obj.genGalvo(galvoYPos, trialTimeSamps);
        
        [galvoX, galvoY] = obj.calib_GalvoPos(galvoX, galvoY); 
        
        s.queueOutputData([laser galvoX galvoY]);
        s.startBackground();
%         s.wait();
%         s.stop();
        
    end
    
    function delete(obj)
        s = obj.s; 
        s.stop(); 
        clear s; 
    end
    
    function waveform = genLaser(obj, laserAmp, laserDur, trialTimeSamps, delayTimeSamps, laserFreq)
        rate = obj.rate;
        laserDurSamps = laserDur * rate;
        waveform = zeros(trialTimeSamps, 1);
        if laserFreq == 0
            waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = laserAmp; 
            [thisRamp, ~] = obj.genRamp(0.002, laserAmp); % 2 ms ramp for laser
            waveform(delayTimeSamps:delayTimeSamps+numel(thisRamp)-1) = thisRamp;
            waveform(delayTimeSamps+laserDurSamps-numel(thisRamp)+1:delayTimeSamps+laserDurSamps) = fliplr(thisRamp);
        else
            swFreq = 40; % oscillation rate
            % i don't want there to be half-waves, so round down to the
            % nearest 25 ms (0.025 sec)
            laserDur = floor(laserDur/0.025)*0.025;
            laserDurSamps = laserDur * rate;
            t = [1:laserDurSamps+1]/rate;
            raisedcos = laserAmp*(1+cos(pi+swFreq*2*pi*t));
            % attenuate if laserDur is longer than 250 ms (5 periods)
            if laserDur >= 0.4
                troughs = [0:1/swFreq:t(end)];
                nAttenPeaks = 4;
                attFactor = cumprod(ones(nAttenPeaks, 1)*0.75);
                attFactor = flip(attFactor);
                for i = nAttenPeaks:-1:1 % iteratively reduce
                    % get index of the nth to last peak
                    [~, peakIdx] = min(abs(t-troughs(end-i)));
                    raisedcos(peakIdx:end) = raisedcos(peakIdx:end)*attFactor(i);
                end 
            end
            waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = raisedcos;
        end

   
    end
    
    function waveform = genGalvo(obj, galvoPos, trialTimeSamps)
        [thisRamp, ~] = obj.genRamp(0.002, galvoPos); % 2 ms ramp for galvo - should be well within the delay
        waveform = zeros(trialTimeSamps, 1) + galvoPos;
        waveform(1:numel(thisRamp)) = thisRamp;  
        waveform(end-numel(thisRamp)+1:end) = fliplr(thisRamp);
   
    end
    
    function [ramp, t] = genRamp(obj, duration, amp)
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
