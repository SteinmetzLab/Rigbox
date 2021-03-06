classdef SignalsInputArduinoRotary < hw.SignalsInput
  %HW.SignalsInputArduinoGeneric 
  %
  % See also HW.SignalsInput
  %
  % Part of Rigbox
  % 2021-03 NS
  
  properties
    serialPortID = 'COM1'; 
    serialBaudRate = 9600;
    serialObj
    verbose = false;
    absPos = 0;
    MillimetresFactor = .0479; % = pi*62.5/4096 where 62.5 is measured diameter of rubber wheel in mm and 4096 is how many ticks you get from one complete revolution 
    ZeroOffset = 0;
    EncoderResolution = 1024; % can read this off the side of the rotary encoder if it's Kubler
  end
  
  
  methods
    function obj = SignalsInputArduinoRotary(name)
      
        obj.Name = name;
        
    end

    function init(obj)
        s = serial(obj.serialPortID,"BaudRate",obj.serialBaudRate);
        fopen(s);
        obj.serialObj = s;
    end
    
    function v = query(obj) 
        
        fprintf(obj.serialObj,'1');
        
        v = [];

        
        while obj.serialObj.BytesAvailable>0
            
            x = fscanf(obj.serialObj,'%f');
%             x = str2num(fscanf(obj.serialObj,'%s'));
            
            % totally hacky way to fix the fact that we get random jumps
            % sometimes
            if x > 2^23; x = x-2^24; end
            if x > 2^15; x = x-2^16; end
            
            if isempty(v); v = x; else; v = v+x; end
        end
        
        if ~isempty(v); obj.absPos = obj.absPos+v; end
              
        if obj.verbose
            fprintf(1, 'Got %s from arduino device %s \n', num2str(v), obj.Name); 
        end  
    end
    
    function pos = readAbsolutePosition(obj)
        obj.query;
        pos = obj.absPos;
    end
    
    function zero(obj)
        obj.absPos = 0;
    end
    
    function delete(obj)
        
        if ~isempty(obj.serialObj)
            fclose(obj.serialObj);
            delete(obj.serialObj);
        end
        
    end
  end
  
end

