classdef TestPathsFixture < matlab.unittest.fixtures.Fixture
  %TESTPATHSFIXTURE Use in place of PathFixture('fixtures')
  %   In R2019b, once dat.paths has been looked up, moving an already-listed
  %   tests/fixtures to the front of the path does not change which
  %   dat.paths is used (nor do rehash, rehash path or clear functions);
  %   removing and re-adding the folder does. PathFixture only moves it, so
  %   tests could run on the real data paths: on 2026-10-27 a teardown
  %   deleted half of the lab share's Subjects folder that way.
  %
  %   It lives here, not in tests/fixtures, because test classes name it in
  %   their SharedTestFixtures attribute, which MATLAB evaluates when it
  %   loads the class, before any fixture has run. tests/fixtures is not on
  %   the path then (adding it is this fixture's job), and tests is not on
  %   it for classes in subfolders such as tests/cortexlab. Rigs load it but
  %   nothing outside tests calls it.
  %
  % See also REPOSFIXTURE, RMTESTDIR

  properties (SetAccess = immutable)
    Folder % the fixtures folder put first on the path
  end

  properties (Access = private)
    OriginalPath
  end

  methods
    function fixture = TestPathsFixture(folder)
      fixture.Folder = absolute(folder);
    end

    function setup(fixture)
      fixture.OriginalPath = path;
      onPath = any(strcmpi(strsplit(path, pathsep), fixture.Folder));
      if onPath
        rmpath(fixture.Folder) % moving it up is not enough in R2019b
      end
      addpath(fixture.Folder)
      expected = fullfile(fixture.Folder, '+dat', 'paths.m');
      actual = which('dat.paths');
      assert(strcmpi(actual, expected), 'Rigbox:tests:TestPathsFixture:wrongPaths', ...
        ['dat.paths is %s, not the test copy %s, even with its folder first on the ' ...
        'path. Tests would use real data folders, so they will not run. Restart ' ...
        'MATLAB and run the tests before anything that calls dat.paths.'], ...
        actual, expected);
      fixture.SetupDescription = sprintf('Put %s first on the path', fixture.Folder);
      fixture.TeardownDescription = 'Restored the path';
    end

    function teardown(fixture)
      if ~isempty(fixture.OriginalPath)
        path(fixture.OriginalPath)
      end
    end
  end

  methods (Access = protected)
    function tf = isCompatible(fixture, other)
      tf = strcmpi(fixture.Folder, other.Folder);
    end
  end
end

function full = absolute(folder)
here = cd(folder);
full = pwd;
cd(here);
end
