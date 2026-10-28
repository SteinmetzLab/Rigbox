classdef ReposFixture < matlab.unittest.fixtures.Fixture
  %REPOSFIXTURE Fixture for using test dat.paths file
  %   Assures test paths are returned, creates a rig config folder for
  %   tests to save a hardware file to and upon teardown removes all
  %   existing test repository folders.
    
  properties (Access = private)
    % MATLAB runs teardown even when setup fails, and then the folders to
    % delete may come from the real dat.paths
    SetupDone = false
  end

  methods
    function setup(fixture)
      % SETUP Ensure correct test paths and create rig config folder
      fixture.SetupDone = false;
      fixture.applyFixture(TestPathsFixture(fileparts(mfilename('fullpath'))))
      
      % Check paths file
      assert(endsWith(which('dat.paths'),...
        fullfile('tests', 'fixtures', '+dat', 'paths.m')));
      fprintf('ReposFixture: dat.paths is %s\n', which('dat.paths'));

      % Check temp mainRepo folder is empty.  An extra safe measure as we
      % don't want to delete important folders by accident!
      mainRepo = dat.reposPath('main', 'master');
      assert(~exist(mainRepo, 'dir') || isempty(file.list(mainRepo)),...
        'Test experiment repo not empty.  Please set another path or manually empty folder');
      
      % Create other folders
      assert(mkdir(getOr(dat.paths, 'rigConfig')), 'Failed to create config directory')
      fixture.SetupDone = true;
    end
    
    function teardown(fixture)
      if ~fixture.SetupDone
        return
      end
      assert(endsWith(which('dat.paths'), fullfile('tests', 'fixtures', '+dat', 'paths.m')), ...
        'Rigbox:tests:ReposFixture:pathsChanged', ...
        'dat.paths is %s at teardown, not the test copy; no test folders removed', ...
        which('dat.paths'));
      testFolders = [dat.reposPath('main');...
        {[dat.reposPath('main', 'm') '2']};...
        {getOr(dat.paths, 'globalConfig')};...
        {getOr(dat.paths, 'localAlyxQueue')}];
      testFolders = testFolders(file.exists(testFolders));
      failed = {};
      for i = 1:numel(testFolders) % try every folder, then report any refusal
        try
          [full, n, bytes] = rmTestDir(testFolders{i});
          fprintf('ReposFixture: removed %s (%d entries, %.1f kB)\n', full, n, bytes / 1e3);
        catch ex
          failed{end+1} = ex.message; %#ok<AGROW>
        end
      end
      clearCBToolsCache
      assert(isempty(failed), 'Rigbox:tests:ReposFixture:notRemoved', ...
        'Test folders not removed: %s', strjoin(failed, ' | '));
    end
  end
end