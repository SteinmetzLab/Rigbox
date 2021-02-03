classdef SignalsOutputArduinoGalvo < hw.SignalsOutput
  %HW.SignalsOutputArduinoGeneric 
  %
  % See also HW.SignalsOutput
  %
  % Part of Rigbox
  % 2020-11 NS
  
  properties
    serialPortID = 'COM1'; 
    serialBaudRate = 9600;
    serialObj = [];
    
    masterObj = []; % keeps a handle to another object that has a serial port, 
                    % and uses that object's port instead of this one
    
    outputChan = 1; %should be 1 or -1 for X or Y
  end
  
  
  methods
    function obj = SignalsOutputArduinoGalvo(name)
      
        obj.Name = name;        
        
    end

    function init(obj)
        
        if isempty(obj.masterObj)
            s = serial(obj.serialPortID,"BaudRate",obj.serialBaudRate);
            fopen(s);
            obj.serialObj = s;
        else
            obj.serialObj = obj.masterObj.serialObj;
        end
        
    end
    
    function command(obj, v) 
        
        fprintf(1, 'Got %s to send to %s \n', num2str(v), obj.Name); 

        fprintf(obj.serialObj,sprintf('%i %i',obj.outputChan, round(v)));
        
    end
    
    function delete(obj)
        
        if ~isempty(obj.masterObj) && ~isempty(obj.serialObj)
            fclose(obj.serialObj);
            delete(obj.serialObj);
        end
        
    end
  end
  
end

