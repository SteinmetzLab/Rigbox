function tests = rmTestDir_test
% RMTESTDIR_TEST Tests rmTestDir and the real dat.paths' INTEST guard.
% Refusal tests use zero limits, so a broken location check still deletes
% nothing.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
here = fileparts(mfilename('fullpath'));
tc.TestData.fixtures = fullfile(here, 'fixtures');
tc.applyFixture(matlab.unittest.fixtures.PathFixture(tc.TestData.fixtures));
tc.TestData.none = struct('entries', 0, 'bytes', 0);
end

function testDeletesInsideFixtures(tc)
d = fullfile(tc.TestData.fixtures, ['rmTestDir_' tmpName()]);
mkdir(fullfile(d, 'sub'));
tc.addTeardown(@removeIfThere, d);
fclose(fopen(fullfile(d, 'sub', 'f.txt'), 'w'));
rmTestDir(d);
tc.verifyFalse(isfolder(d));
end

function testRefusesOutsideFixtures(tc)
d = tempname;
mkdir(d);
tc.addTeardown(@() rmdir(d, 's'));
tc.verifyError(@() rmTestDir(d, tc.TestData.none), 'Rigbox:tests:rmTestDir:outsideFixtures');
tc.verifyTrue(isfolder(d));
end

function testRefusesEscapeWithDotDot(tc)
% a path written inside fixtures that resolves to a sibling of it
name = ['rmTestDir_' tmpName()];
sibling = fullfile(fileparts(tc.TestData.fixtures), name);
mkdir(sibling);
tc.addTeardown(@removeIfThere, sibling);
d = fullfile(tc.TestData.fixtures, '..', name);
tc.verifyError(@() rmTestDir(d, tc.TestData.none), 'Rigbox:tests:rmTestDir:outsideFixtures');
tc.verifyTrue(isfolder(sibling));
end

function testRefusesFixturesItself(tc)
% zero limits: should the location check fail, the size check still refuses
fx = tc.TestData.fixtures;
tc.verifyError(@() rmTestDir(fx, tc.TestData.none), 'Rigbox:tests:rmTestDir:outsideFixtures');
tc.verifyError(@() rmTestDir([fx filesep], tc.TestData.none), ...
  'Rigbox:tests:rmTestDir:outsideFixtures');
tc.verifyTrue(isfolder(fx));
end

function testRefusesTooManyEntries(tc)
d = makeTree(tc, 3, 4);                          % 3 folders of 4 files: 15 entries
limits = struct('entries', 10, 'bytes', 1e9);
tc.verifyError(@() rmTestDir(d, limits), 'Rigbox:tests:rmTestDir:tooBig');
tc.verifyTrue(isfile(fullfile(d, 'sub1', 'f1.txt')));   % nothing deleted
end

function testRefusesTooManyBytes(tc)
d = makeTree(tc, 1, 2, 600);                     % 2 files of 600 bytes
limits = struct('entries', 1000, 'bytes', 1000);
tc.verifyError(@() rmTestDir(d, limits), 'Rigbox:tests:rmTestDir:tooBig');
tc.verifyTrue(isfolder(d));
end

function testDeletesWithinLimits(tc)
d = makeTree(tc, 3, 4, 10);
[full, n, bytes] = rmTestDir(d, struct('entries', 15, 'bytes', 120)); % exactly at both limits
tc.verifyFalse(isfolder(d));
tc.verifyEqual(lower(full), lower(d));
tc.verifyEqual([n bytes], [15 120]);
end

function testDefaultLimitsAllowTestSizedFolders(tc)
% about the size of dat_test's repository (from its setup code)
d = makeTree(tc, 120, 1, 100);
rmTestDir(d);
tc.verifyFalse(isfolder(d));
end

function testRealPathsRefuseInTest(tc)
% a copy of the real +dat/paths.m in a new folder, which then takes
% precedence (a newly added folder does, even in R2019b)
real = fullfile(fileparts(fileparts(mfilename('fullpath'))), '+dat', 'paths.m');
copyDir = tempname;
mkdir(fullfile(copyDir, '+dat'));
copyfile(real, fullfile(copyDir, '+dat', 'paths.m'));
tc.addTeardown(@() rmdir(copyDir, 's'));
tc.applyFixture(matlab.unittest.fixtures.PathFixture(copyDir));
old = setTestFlag(true);
tc.addTeardown(@setTestFlag, old);
tc.verifyError(@() dat.paths(), 'Rigbox:dat:paths:inTest');
end

function d = makeTree(tc, nFolders, nFiles, nBytes)
% A folder inside tests/fixtures with nFolders subfolders of nFiles files
% of nBytes bytes each (default 0); removed at teardown if a test left it
if nargin < 4, nBytes = 0; end
d = fullfile(tc.TestData.fixtures, ['rmTestDir_' tmpName()]);
tc.addTeardown(@removeIfThere, d);
for i = 1:nFolders
  sub = fullfile(d, sprintf('sub%d', i));
  mkdir(sub);
  for j = 1:nFiles
    fid = fopen(fullfile(sub, sprintf('f%d.txt', j)), 'w');
    fwrite(fid, zeros(1, nBytes, 'uint8'));
    fclose(fid);
  end
end
end

function removeIfThere(d)
if isfolder(d), rmdir(d, 's'); end
end

function n = tmpName()
% A unique folder name, without Java (absent in some MATLAB installs)
[~, n] = fileparts(tempname);
end
