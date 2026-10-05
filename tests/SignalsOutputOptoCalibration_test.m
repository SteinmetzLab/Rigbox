classdef SignalsOutputOptoCalibration_test < matlab.unittest.TestCase
    % Tests hw.SignalsOutputOpto.loadCalibration against calibration files in
    % a temporary folder. No DAQ session opens and the share is never read.

    properties
        Dir
    end

    methods (TestMethodSetup)
        function makeCalibDir(tc)
            tc.Dir = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            mkdir(fullfile(tc.Dir, 'laserModCalib'));
            tc.writeCalib(struct('slope638', 1.66, 'int638', -0.11, 'slope594', 1.01, ...
                'int594', -0.31, 'mmX', 1.11, 'mmY', -1.08, 'offX', -0.98, 'offY', 0.86));
        end
    end

    methods (Access = private)
        function writeCalib(tc, c)
            d = tc.Dir;
            calibSlope = c.slope638; calibIntercept = c.int638; %#ok<NASGU>
            save(fullfile(d, 'laserModCalib', 'laserModCalib638.mat'), 'calibSlope', 'calibIntercept');
            calibSlope = c.slope594; calibIntercept = c.int594; %#ok<NASGU>
            save(fullfile(d, 'laserModCalib', 'laserModCalib594.mat'), 'calibSlope', 'calibIntercept');
            mmPerV_X = c.mmX; save(fullfile(d, 'mmPerV_X.mat'), 'mmPerV_X');
            mmPerV_Y = c.mmY; save(fullfile(d, 'mmPerV_Y.mat'), 'mmPerV_Y');
            bregmaOffset_X = c.offX; save(fullfile(d, 'bregmaOffset_X.mat'), 'bregmaOffset_X');
            bregmaOffset_Y = c.offY; save(fullfile(d, 'bregmaOffset_Y.mat'), 'bregmaOffset_Y');
        end

        function obj = makeObj(tc, cls)
            obj = feval(cls, 'test', 'Dev3');
            obj.calibDir = tc.Dir;
        end
    end

    methods (Test)
        function loadsEveryValue(tc)
            obj = tc.makeObj('hw.SignalsOutputOpto638');
            tc.verifyWarningFree(@() obj.loadCalibration(true));
            tc.verifyEqual([obj.VmWSlope obj.VmWIntercept obj.mmPerV_X obj.mmPerV_Y ...
                obj.bregmaOffset_X obj.bregmaOffset_Y], [1.66 -0.11 1.11 -1.08 -0.98 0.86]);
        end

        function eachLaserReadsItsOwnFile(tc)
            obj = tc.makeObj('hw.SignalsOutputOpto594');
            obj.loadCalibration(true);
            tc.verifyEqual([obj.VmWSlope obj.VmWIntercept], [1.01 -0.31]);
            obj = tc.makeObj('hw.SignalsOutputOptoTwoSpots594');
            obj.loadCalibration(true);
            tc.verifyEqual([obj.VmWSlope obj.VmWIntercept], [1.01 -0.31]);
            obj = tc.makeObj('hw.SignalsOutputOptoTwoSpots638');
            obj.loadCalibration(true);
            tc.verifyEqual([obj.VmWSlope obj.VmWIntercept], [1.66 -0.11]);
        end

        function reloadPicksUpANewerCalibration(tc)
            % The bug this fixes: a calibration saved after expServer launched.
            obj = tc.makeObj('hw.SignalsOutputOpto638');
            obj.loadCalibration(true);
            tc.writeCalib(struct('slope638', 2, 'int638', -0.2, 'slope594', 1, ...
                'int594', 0, 'mmX', 1.2, 'mmY', -1.2, 'offX', -1, 'offY', 1));
            obj.loadCalibration(true);
            tc.verifyEqual([obj.VmWSlope obj.VmWIntercept obj.mmPerV_X obj.mmPerV_Y ...
                obj.bregmaOffset_X obj.bregmaOffset_Y], [2 -0.2 1.2 -1.2 -1 1]);
        end

        function strictMissingFileErrorsAndChangesNothing(tc)
            obj = tc.makeObj('hw.SignalsOutputOpto638');
            obj.loadCalibration(true);
            before = [obj.VmWSlope obj.mmPerV_X obj.mmPerV_Y obj.bregmaOffset_X];
            % A newer laser calibration, but a galvo file has gone missing.
            tc.writeCalib(struct('slope638', 2, 'int638', -0.2, 'slope594', 1, ...
                'int594', 0, 'mmX', 1.2, 'mmY', -1.2, 'offX', -1, 'offY', 1));
            delete(fullfile(tc.Dir, 'mmPerV_Y.mat'));
            tc.verifyError(@() obj.loadCalibration(true), 'SignalsOutputOpto:loadCalibration:failed');
            tc.verifyEqual([obj.VmWSlope obj.mmPerV_X obj.mmPerV_Y obj.bregmaOffset_X], before);
        end

        function strictUnreachableDirErrors(tc)
            % Fresh object (identity defaults) and no share: must not run.
            obj = tc.makeObj('hw.SignalsOutputOpto638');
            obj.calibDir = fullfile(tc.Dir, 'nope');
            tc.verifyError(@() obj.loadCalibration(true), 'SignalsOutputOpto:loadCalibration:failed');
            tc.verifyError(@() obj.loadCalibration(), 'SignalsOutputOpto:loadCalibration:failed');
        end

        function lenientWarnsAndKeepsWhatItCannotRead(tc)
            obj = tc.makeObj('hw.SignalsOutputOpto638');
            obj.mmPerV_Y = -7;
            delete(fullfile(tc.Dir, 'mmPerV_Y.mat'));
            tc.verifyWarning(@() obj.loadCalibration(false), 'SignalsOutputOpto:loadCalibration:failed');
            tc.verifyEqual(obj.mmPerV_Y, -7);
            tc.verifyEqual(obj.mmPerV_X, 1.11);  % the readable ones still load
        end

        function rejectsBadValues(tc)
            obj = tc.makeObj('hw.SignalsOutputOpto638');
            mmPerV_X = 0; save(fullfile(tc.Dir, 'mmPerV_X.mat'), 'mmPerV_X'); %#ok<NASGU>
            tc.verifyError(@() obj.loadCalibration(true), 'SignalsOutputOpto:loadCalibration:failed');
            mmPerV_X = [1 2]; save(fullfile(tc.Dir, 'mmPerV_X.mat'), 'mmPerV_X'); %#ok<NASGU>
            tc.verifyError(@() obj.loadCalibration(true), 'SignalsOutputOpto:loadCalibration:failed');
            wrongName = 1; save(fullfile(tc.Dir, 'mmPerV_X.mat'), 'wrongName'); %#ok<NASGU>
            tc.verifyError(@() obj.loadCalibration(true), 'SignalsOutputOpto:loadCalibration:failed');
        end

        function printsWhichFilesItUsed(tc)
            obj = tc.makeObj('hw.SignalsOutputOpto638');
            out = evalc('obj.loadCalibration(true)');
            tc.verifySubstring(out, 'test calibration:');
            tc.verifySubstring(out, 'laserModCalib638.mat 20');
            tc.verifySubstring(out, 'bregmaOffset_Y.mat 20');
        end

        function signalsExpReloadsAtExperimentStart(tc)
            % SignalsExp cannot be constructed without Psychtoolbox, so check
            % the hook is in the constructor's output wiring by source.
            src = fileread(which('exp.SignalsExp'));
            tc.verifySubstring(src, ...
                'rig.signalsOutputs.(outputNames{m}).loadCalibration(true);');
        end
    end
end
