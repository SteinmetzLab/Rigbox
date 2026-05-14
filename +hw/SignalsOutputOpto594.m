classdef SignalsOutputOpto594 < hw.SignalsOutputOpto
  %SIGNALSOUTPUTOPTO594  594 nm (orange) laser on AO3.
  %
  % See also HW.SIGNALSOUTPUTOPTO, HW.SIGNALSOUTPUTOPTO638

  properties (Constant)
    laserAOChannel = 'ao3';
    laserCalibFile = 'laserModCalib594.mat';
  end

  methods
    function obj = SignalsOutputOpto594(name, devID)
        obj@hw.SignalsOutputOpto(name, devID);
    end
  end

end
