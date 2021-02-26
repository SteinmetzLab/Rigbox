classdef SignalsInput < matlab.mixin.Heterogeneous & handle
  %HW.SignalsOoutput Code to specify an output channel for a signals
  %experiment
  %   This is an abstract class. 
  %
  %   Below is a list of some subclasses and their functions:
  %     hw.ArduinoGeneric - sends the command as a string to the arduino
  %     hw.ArduinoGalvo - sends the command with a specific format for the
  %       galvo controller
  %
  %   The hw.devices routine will call "init". The signals experiment will
  %   call "command" whenever a signal with a name matching the object
  %   instance gets a value.
  %
  % Part of Rigbox
  
  % 2020-11 NS created
  
  properties
    % The name of the output, for easy identification
    Name

  end  
  
  methods (Abstract)
    % Called when hw.devices is called
    init(obj) 
    
    % Called on each main loop of signals. The resulting value gets posted
    % into a signal called inputs.[Name]
    v = query(obj) 
    
  end
  
end

