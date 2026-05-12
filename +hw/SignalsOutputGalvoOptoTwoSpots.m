classdef SignalsOutputGalvoOptoTwoSpots < hw.SignalsOutput
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
    function obj = SignalsOutputGalvoOptoTwoSpots(name,devID)
      
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
        galvoPos1x = v(3);
        galvoPos1y = v(4);
        galvoPos2x = v(5);
        galvoPos2y = v(6);
        
        galvoPos1 = [galvoPos1x, galvoPos2x]; % both x coords
        galvoPos2 = [galvoPos1y, galvoPos2y]; % both y coords
        
        trialTimeS = laserDurS;
        % convert into NI samples
        trialTimeSamps = round(trialTimeS*rate);

        % create the waveforms for each component
        laserAmp_V = (laserAmp-obj.VmWIntercept)/obj.VmWSlope; % convert mW input to V
        
        [laser, galvoX, galvoY] = obj.genWaveforms(laserAmp_V, laserDurS, galvoPos1, galvoPos2, trialTimeSamps);
        [galvoX, galvoY] = obj.calib_GalvoPos(galvoX, galvoY);
        
        s.queueOutputData([laser galvoX galvoY]);
        s.startBackground();
        
    end
    
    function delete(obj)
        s = obj.s; 
        s.stop(); 
        clear s; 
    end
    
    function [laser, galvoX, galvoY] = genWaveforms(obj, laserAmp, laserDur, ...
            galvoPos1, galvoPos2, trialTimeSamps)
        
        rate = obj.rate;
        laserDurSamps = laserDur * rate;
        waveform = zeros(trialTimeSamps, 1);
        
        lasOnDur = 0.005; % s, time ON at each spot
        pRate = 40; % hz
        cycleDur = 1/pRate; % s
        moveDur = 0.006; % s

        tMove = (0:1/obj.rate:moveDur)';
        halfCos = (-cos(pi*tMove/moveDur)+1)/2;
        moveSamps = numel(halfCos); 

        % step 1: move to first position
        gx = halfCos*diff(galvoPos1)+galvoPos1(1);
        gy = halfCos*diff(galvoPos2)+galvoPos2(1);
        las = zeros(moveSamps,1); 

        % step 2: laser on
        lasSamps = lasOnDur*obj.rate;
        gx = [gx; galvoPos1(2)*ones(lasSamps,1)];
        gy = [gy; galvoPos2(2)*ones(lasSamps,1)];
        las = [las; laserAmp*ones(lasSamps,1)];

        % step 3: wait until next move
        waitDur = (cycleDur-2*moveDur-2*lasOnDur)/2;
        waitSamps = round(waitDur*obj.rate);
        gx = [gx; galvoPos1(2)*ones(waitSamps,1)];
        gy = [gy; galvoPos2(2)*ones(waitSamps,1)];
        las = [las; zeros(waitSamps,1)];

        % step 4: move to second position
        gx = [gx; flipud(halfCos*diff(galvoPos1)+galvoPos1(1))];
        gy = [gy; flipud(halfCos*diff(galvoPos2)+galvoPos2(1))];
        las = [las; zeros(moveSamps,1)];

        % step 5: laser on
        gx = [gx; galvoPos1(1)*ones(lasSamps,1)];
        gy = [gy; galvoPos2(1)*ones(lasSamps,1)];
        las = [las; laserAmp*ones(lasSamps,1)];

        % step 6: wait again
        gx = [gx; galvoPos1(1)*ones(waitSamps,1)];
        gy = [gy; galvoPos2(1)*ones(waitSamps,1)];
        las = [las; zeros(waitSamps,1)];

        % repeat cycle
        nCycle = laserDur*pRate;
        gx = repmat(gx,nCycle, 1);
        gy = repmat(gy,nCycle, 1);
        las = repmat(las,nCycle, 1);
        
        laser = las;
        galvoX = gx;
        galvoY = gy;
    end
    
    function [galvoX, galvoY] = calib_GalvoPos(obj, galvoX, galvoY)
        galvoX = galvoX/obj.mmPerV_X + obj.bregmaOffset_X;
        galvoY = galvoY/obj.mmPerV_Y + obj.bregmaOffset_Y;
    end
    
  end
  
end
