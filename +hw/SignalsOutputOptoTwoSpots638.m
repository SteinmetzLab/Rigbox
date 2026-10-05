classdef SignalsOutputOptoTwoSpots638 < hw.SignalsOutputOptoTwoSpots
  %SIGNALSOUTPUTOPTOTWOSPOTS638  Two scanned spots, 638 nm (red) laser on AO0.
  %
  % See also HW.SIGNALSOUTPUTOPTOTWOSPOTS, HW.SIGNALSOUTPUTOPTO638

  properties (Constant)
    laserAOChannel = 'ao0';
    laserCalibFile = 'laserModCalib638.mat';
  end

  methods
    function obj = SignalsOutputOptoTwoSpots638(name, devID)
        obj@hw.SignalsOutputOptoTwoSpots(name, devID);
    end
  end

end
