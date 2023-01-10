classdef SignalsOutputArduinoTTL < hw.SignalsOutput
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
    function obj = SignalsOutputArduinoTTL(name, sID)
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
    
    function command(obj, v) 
        
        fprintf(1, 'Got %s to send to %s -- ', num2str(v), obj.Name); 

        if (ischar(v)&&v=='0') || (isnumeric(v)&&v==0) || (iscell(v)&&v{1}==0)
            fprintf(1, 'sending 0, to flip state\n')
            fprintf(obj.serialObj,sprintf('%i',num2str(0)));
        else
            fprintf(1, 'sending 1, to send 1 ms TTL\n')
            fprintf(obj.serialObj,sprintf('%i',num2str(1)));
        end
    end
    
    function delete(obj)
        
        if ~isempty(obj.serialObj)
            fclose(obj.serialObj);
            delete(obj.serialObj);
        end
        
    end
  end
  
end

