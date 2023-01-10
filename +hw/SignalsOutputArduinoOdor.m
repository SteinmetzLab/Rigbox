classdef SignalsOutputArduinoOdor < hw.SignalsOutput
  %HW.SignalsOutputArduinoTTL
  %
  % works with arduinoTTLout.ino. Sends 1 ms step pulse on any command
  % other than 0. Command of 0 flips state. 
  %
  % See also HW.SignalsOutput
  %
  % Part of Rigbox
  % 2020-11 NS
  
  properties
    serialPortID = 'COM1'; 
    serialBaudRate = 9600;
    serialObj
  end
  
  
  methods
    function obj = SignalsOutputArduinoOdor(name, sID)
      if ~isempty(sID)
          obj.serialPortID = sID;
        end
        obj.Name = name;
        
    end

    function init(obj)
        s = serial(obj.serialPortID,"BaudRate",obj.serialBaudRate);
        fopen(s);
        obj.serialObj = s;
    end
    
    function command(obj, dt) 
        
        fprintf(1, 'Got %s to send to %s \n ', num2str(dt), obj.Name); 
        fprintf(obj.serialObj,sprintf('%i',round(dt*1000)));
        
    end
    
    function delete(obj)
        
        if ~isempty(obj.serialObj)
            fclose(obj.serialObj);
            delete(obj.serialObj);
        end
        
    end
  end
  
end

