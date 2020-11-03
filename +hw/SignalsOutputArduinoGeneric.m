classdef SignalsOutputArduinoGeneric < hw.SignalsOutput
  %HW.SignalsOutputArduinoGeneric 
  %
  % See also HW.SignalsOutput
  %
  % Part of Rigbox
  % 2020-11 NS
  
  properties
    serialPortID = 'COM7'; 
    serialBaudRate = 9600;
    serialObj
  end
  
  
  methods
    function obj = SignalsOutputArduinoGeneric(name)
      
        obj.Name = name;
        
    end

    function init(obj)
        s = serial(obj.serialPortID,"BaudRate",obj.serialBaudRate);
        fopen(s);
        obj.serialObj = s;
    end
    
    function command(obj, v) 
        
        fprintf(1, 'Got %s to send to %s \n', num2str(v), obj.Name); 

        if ischar(v)
            fprintf(obj.serialObj,v);
        elseif isnumeric(v)
            fprintf(obj.serialObj,sprintf('%s',num2str(v)));
        elseif iscell(v)
            fprintf(obj.serialObj,sprintf('%s',v{1}));
        end
    end
    
    function delete(obj)
        fclose(obj.serialObj);
        delete(obj.serialObj);
    end
  end
  
end

