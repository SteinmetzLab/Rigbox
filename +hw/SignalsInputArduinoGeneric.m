classdef SignalsInputArduinoGeneric < hw.SignalsInput
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
        
        fprintf(obj.serialObj,'1');
        
        v = [];
        tic
%         while obj.serialObj.BytesAvailable==0
%             x=5;
%         end
        
        while obj.serialObj.BytesAvailable>0
            %v(end+1) = str2num(fscanf(obj.serialObj,'%s'));
            %v(end+1) = fscanf(obj.serialObj,'%f');
            %v(end+1) = fread(obj.serialObj, 1, '*double');
            v = fread(obj.serialObj, 1, 'int8');
        end
        toc
              
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

