classdef SignalsOutputGalvoOptoFG < hw.SignalsOutput
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
  end
  
  
  methods
    function obj = SignalsOutputGalvoOptoFG(name,devID)
      
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
        % laserRamp...?
        % galvoRamp...?
        
        fprintf(1, 'Laser on %2.1fV %3.2fS. Galvo X, Y: %4.3f, %4.3f\n. Freq(bool) %2.1f.', ...
            laserAmp, laserDurS, galvoXPos, galvoYPos, laserFreq); 
        
        % set timing parameters for this trial
%         delayTimeS = 0.2+rand*(laserDelay+0.2);

        % 0.05 for time to turn laser off
        trialTimeS = laserDelay + laserDurS + 0.001;

        % convert into NI samples
        delayTimeSamps = round(laserDelay*rate);
        trialTimeSamps = round(trialTimeS*rate);

        % create the waveforms for each component
        laser = obj.genLaser(laserAmp, laserDurS, trialTimeSamps, delayTimeSamps, laserFreq);
        galvoX = obj.genGalvo(galvoXPos, trialTimeSamps);
        galvoY = obj.genGalvo(galvoYPos, trialTimeSamps);

        s.queueOutputData([laser galvoX galvoY]);
        s.startForeground();
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
        ramp_time=14;
        rampSamps =  ramp_time * rate;
        laserDurSamps = laserDur * rate;
        waveform = zeros(trialTimeSamps, 1);
        waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = laserAmp; 
%         waveform(delayTimeSamps:delayTimeSamps+rampSamps-1) = laserAmp * (0:rampSamps-1) / rampSamps;
%         if laserFreq == 0
%             waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = laserAmp; 
%         else
%             swFreq = 40 % oscillation rate
%             t = [1:laserDurSamps+1]/rate;
%             raisedcos = laserAmp*(1+cos(pi+swFreq*2*pi*t));
%             waveform(delayTimeSamps:delayTimeSamps+laserDurSamps) = raisedcos;
%         end

   
    end
    
    function waveform = genGalvo(obj, galvoPos, trialTimeSamps)
        [thisRamp, ~] = obj.genRamp(0.001, galvoPos);
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
    
  end
  
end

