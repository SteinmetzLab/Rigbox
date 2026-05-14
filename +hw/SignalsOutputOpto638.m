classdef SignalsOutputOpto638 < SignalsOutputOpto
  %SIGNALSOUTPUTOPTO638  638 nm (red) laser on AO0.
  %
  % See also HW.SIGNALSOUTPUTOPTO, HW.SIGNALSOUTPUTOPTO594

  properties (Constant)
    laserAOChannel = 'ao0';
    laserCalibFile = 'laserModCalib638.mat';
  end

  methods
    function obj = SignalsOutputOpto638(name, devID)
        obj@SignalsOutputOpto(name, devID);
    end
  end

end
