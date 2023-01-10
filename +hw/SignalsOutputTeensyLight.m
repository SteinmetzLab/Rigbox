classdef SignalsOutputTeensyLight < hw.SignalsOutput
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
  end
  
  
  methods
    function obj = SignalsOutputTeensyLight(name,port)
      
        obj.Name = name;        
        obj.serialPortID = port;
        
    end

    function init(obj)
       
        s = serial(obj.serialPortID,"BaudRate",obj.serialBaudRate);
        fopen(s);
        obj.serialObj = s;
        
    end
    
    function command(obj, v) 
        
        fprintf(1, 'Got %s to send to %s \n', num2str(v), obj.Name); 

        fprintf(obj.serialObj,num2str(v));
        
    end
    
    function delete(obj)
        fclose(obj.serialObj);
        delete(obj.serialObj);
    end
  end
  
end

