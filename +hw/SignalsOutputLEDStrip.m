classdef SignalsOutputLEDStrip < hw.SignalsOutput
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
    function obj = SignalsOutputLEDStrip(name,devID)
      
        obj.Name = name;        
        obj.devID = devID;
        
    end

    function init(obj)
        newS = daq.createSession('ni');
        newS.addAnalogOutputChannel(obj.devID, 'ao3', 'Voltage');
        newS.Rate = obj.rate;
        obj.s = newS;
    end
    
    function command(obj, v)
        s = obj.s;
        rate = obj.rate;
        
        % extract the specified parameters
        amp = v(1);
        durS = v(2);
        freq = v(3); 
        
        fprintf(1, 'LED on %2.1fV %3.2fS at %2.0fHz.\n', ...
            amp, durS, freq); 
        
        % create the waveforms for each component
        waveform = obj.genLEDWave(amp, durS, freq);

        s.queueOutputData([waveform']);
        s.startBackground();
%         s.wait();
%         s.stop();
        
    end
    
    function delete(obj)
        s = obj.s; 
        s.stop(); 
        clear s; 
    end
    
    function waveform = genLEDWave(obj, amp, durS, freq)
        rate = obj.rate;
        t = 0:1/rate:durS;
        waveform = amp*sin(t*2*pi*freq);
    end
    
    function [ramp, t] = genRamp(obj, duration, amp)
        rate = obj.rate; 
        t = 0:1/rate:duration;
        f = 1/(duration*2);
        ramp = amp*0.5*(1-cos(t*(2*pi*f))); 
    end
  end
  
end

