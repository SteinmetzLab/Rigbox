classdef SignalsOutputGalvoOptoCircle < hw.SignalsOutput
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
    function obj = SignalsOutputGalvoOptoCircle(name,devID)
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
        laserDelay = v(2);
        circleDurS = v(3);
        nCircles = v(4);
        circleCenterX = v(5);
        circleCenterY = v(6);
        circleRadius = v(7);
        circleCW = v(8);
        
        fprintf(1, 'Laser on %2.1fV %3.2f revlutions. CW(bool) %2.1f.', ...
            laserAmp, nCircles, circleCW); 

        % 0.001 for time to turn laser off
        laserDurS = circleDurS * nCircles;
        laserDurSamps = laserDurS * rate;
        trialTimeS = laserDelay + laserDurS + 0.001;

        % convert into NI samples
        delayTimeSamps = round(laserDelay*rate);
        trialTimeSamps = round(trialTimeS*rate);

        % create the waveforms for each component
        laserAmp_V = (laserAmp-obj.VmWIntercept)/obj.VmWSlope; % convert mW input to V
        laser = obj.genLaser(laserAmp_V, laserDurSamps, trialTimeSamps, delayTimeSamps);
        
        
        [galvoX, galvoY] = obj.genXYGalvo(trialTimeSamps, delayTimeSamps, circleCenterX, circleCenterY, laserDurS, circleDurS, circleRadius, circleCW);
        [galvoX, galvoY] = obj.calib_GalvoPos(galvoX, galvoY); 
        s.queueOutputData([laser galvoX galvoY]);
        s.startBackground();
    end
    
    function delete(obj)
        s = obj.s; 
        s.stop(); 
        clear s; 
    end
    
    function waveform = genLaser(obj, laserAmp, laserDurSamps, trialTimeSamps, delayTimeSamps)
        rate = obj.rate;
        waveform = zeros(trialTimeSamps, 1);
        waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = laserAmp; 
    end
    
    function [galvoX, galvoY] = calib_GalvoPos(obj, galvoX, galvoY)
        galvoX = galvoX/obj.mmPerV_X + obj.bregmaOffset_X;
        galvoY = galvoY/obj.mmPerV_Y + obj.bregmaOffset_Y;
    end
    
    function [waveformX, waveformY] = genXYGalvo(obj, trialTimeSamps, delayTimeSamps, circleCenterX, circleCenterY, laserDurS, circleDurS, circleRadius, circleCW)
        rate = obj.rate;
        dt = 1/rate; 
        laserDurSamps = laserDurS * rate;
        t = (0:dt:laserDurS)'; 
        
        F = 1/circleDurS; % one full circle turn is one period
        
        % same whether CW or CCW
        y = circleCenterY + (circleRadius * cos(2*pi*F*t));
        
        % x has a phase shift of pi if CW - note that Y is inverted
        % because a higher voltage in Y is more posterior
        if circleCW == 0 % only a pi phase shift in x
            x = circleCenterX + (circleRadius * sin(2*pi*F*t));
        elseif circleCW == 1
            x = circleCenterX + (circleRadius * sin(2*pi*F*t+pi));
        end

        waveformX = zeros(trialTimeSamps, 1);
        waveformY = zeros(trialTimeSamps, 1);
        waveformX(delayTimeSamps:delayTimeSamps+laserDurSamps) = x;
        waveformY(delayTimeSamps:delayTimeSamps+laserDurSamps) = y;
        
        % set last entry to 0 to reset galvos
        waveformX(end) = 0;
        waveformY(end) = 0;
        
    end

  end
  
end
