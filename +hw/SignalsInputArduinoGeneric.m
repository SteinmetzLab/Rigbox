classdef SignalsInputArduinoGeneric < hw.SignalsInput
  %HW.SignalsOutputArduinoGeneric 
  %
  % See also HW.SignalsOutput
  %
  % Part of Rigbox
  % 2020-11 NS
  
  properties
    serialPortID = 'COM1'; 
    serialBaudRate = 9600;
    serialObj
    verbose = true; 
  end
  
  
  methods
    function obj = SignalsInputArduinoGeneric(name)
      
        obj.Name = name;
        
    end

    function init(obj)
        s = serial(obj.serialPortID,"BaudRate",obj.serialBaudRate);
        fopen(s);
        obj.serialObj = s;
    end
    
    function v = query(obj) 
        
        fprintf(obj.serialObj,'q');
        
        v = fscanf(obj.serialObj);
        
        if obj.verbose
            fprintf(1, 'Got %s from arduino device %s \n', num2str(v), obj.Name); 
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

