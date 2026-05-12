classdef SignalsOutputSyringePump < hw.SignalsOutput
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
    rpm=3.33;%rotations per minute
    voltage=1; %digital
    delay=0.001; %buffer in seconds
  end
  
  
  methods
    function obj = SignalsOutputSyringePump(name,devID)
      
        obj.Name = name;        
        obj.devID = devID;
        
    end
    
    function init(obj)
        newS = daq.createSession('ni');
        newS.addAnalogOutputChannel(obj.devID, 'ao3', 'Voltage'); % galvo x
        newS.addDigitalChannel(obj.devID, 'port0/line0', 'OutputOnly');
%         newS.addDigitalChannel(obj.devID, 'port0/line8', 'OutputOnly');
        %         newS.addAnalogOutputChannel(obj.devID, 'ao5', 'Voltage');
        newS.Rate = obj.rate;
        obj.s = newS;
    end
    function command(obj,v)
        dt=obj.pulseDuration(v(1), v(2));
%         fprintf('syringe area %s \n', num2str(v(1)));
%         fprintf('volume %s ul \n', num2str(v(2)));
        
        s = obj.s;
        % convert into NI samples
        upTime = round(dt*obj.rate);
        pump=obj.genPump(upTime);
        clock=zeros(size(pump));
        if dt>0.01
            fprintf('pump1 on for %s seconds, %s ul \n', num2str(sum(pump>0)/obj.rate,3), num2str(v(2)));
            s.queueOutputData([clock pump]);
            s.startBackground();
        else
        end
        
    end
    function dt= pulseDuration(obj, syringe, volume)
        flowrate=0.19538*obj.rpm*syringe*1000/60; %in ul/s
        if volume>0
            dt=volume/flowrate;   
        else
            dt=0;
        end
    end
    
    function waveform=genPump(obj, upTime)
        delaysamps=round(obj.delay*obj.rate);
        waveform = zeros(upTime+2*delaysamps, 1);
        waveform(delaysamps:upTime+delaysamps)=obj.voltage;
    end
 
    
    function delete(obj)
        s = obj.s; 
        s.stop(); 
        clear s; 
    end  
    
  end
  
end
