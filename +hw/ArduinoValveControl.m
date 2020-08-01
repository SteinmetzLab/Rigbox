classdef ArduinoValveControl < handle
  %HW.REWARDVALVECONTROL Controls a valve via a DAQ to deliver reward
  %   Must (currently) be sole outputer on DAQ session
  %   TODO
  %
  % Part of Rigbox
  
  % 2013-01 CB created
  
  properties
    Calibrations
    % deliveries with measured volumes for calibration.
    % This should be a struct array with fields 'durationSecs' &
    % 'volumeMicroLitres' indicating the duration the valve was open, and the
    % measured volume (in ul) for that delivery. These points are interpolated
    % to work out how long to open the valve for arbitrary volumes.
    WaterType = 'Water'
    % The type of water dispenced by the rig.  This is used to populate the
    % water_type field in Alyx sessions.
    serialPortID = 'COM4'; 
    serialBaudRate = 9600;
    serialObj
    DefaultValue = 0; % ??
    DefaultCommand = 2.0; % uL default reward size
  end
  
  methods
    function obj = ArduinoValveControl()
        
        s = serial(obj.serialPortID,"BaudRate",obj.serialBaudRate);
        fopen(s);
        obj.serialObj = s;
      %obj@hw.PulseSwitcher;
      obj.ParamsFun = [];
    end
    
    function dt = pulseDuration(obj, ul)
      % Returns the duration the valve should be opened for to deliver
      % microLitres of reward. Is calibrated using interpolation of the
      % measured delivery data.
      recent = obj.Calibrations(end).measuredDeliveries;
      
      volumes = [recent.volumeMicroLitres];
      durations = [recent.durationSecs];
      if ul > max(volumes) || ul < min(volumes)
        warning('Warning requested delivery of %.1f is outside calibration range',...
          ul);
      end
      dt = interp1(volumes, durations, ul, 'pchip');
    end
    
    function ul = sizeFromDuration(obj, dt)
      % Returns the amount of reward the valve would delivery by being open
      % for the duration specified. Is calibrated using interpolation of the
      % measured delivery data.
      volumes = [obj.MeasuredDeliveries.volumeMicroLitres];
      durations = [obj.MeasuredDeliveries.durationSecs];
      ul = interp1(durations, volumes, dt, 'pchip');
    end
    
    function dt = waveform(obj, ~, v)
        dt = obj.pulseDuration(v);
    end
    
    function output(obj,dt)
        if iscell(dt); dt = dt{1}; end
        fprintf(obj.serialObj,sprintf('%i',round(dt*1000)));
    end
    
    function delete(obj)
        fclose(obj.serialObj);
        delete(obj.serialObj);
    end
        
  end
  
end

