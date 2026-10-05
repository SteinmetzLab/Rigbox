classdef SignalsOutputOptoTwoSpots594 < hw.SignalsOutputOptoTwoSpots
  %SIGNALSOUTPUTOPTOTWOSPOTS594  Two scanned spots, 594 nm (orange) laser on AO3.
  %
  % See also HW.SIGNALSOUTPUTOPTOTWOSPOTS, HW.SIGNALSOUTPUTOPTO594

  properties (Constant)
    laserAOChannel = 'ao3';
    laserCalibFile = 'laserModCalib594.mat';
  end

  methods
    function obj = SignalsOutputOptoTwoSpots594(name, devID)
        obj@hw.SignalsOutputOptoTwoSpots(name, devID);
    end
  end

end
