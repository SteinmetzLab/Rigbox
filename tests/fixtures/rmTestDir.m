function [full, nEntries, nBytes] = rmTestDir(folder, limits)
% RMTESTDIR Recursive delete for tests: only inside tests/fixtures, and only
% folders of test size (by default 5000 entries, 100 MB; from its setup code,
% dat_test makes a few hundred folders of small files). Tests get their
% folders from dat.paths, which can be the real data paths.
%
% See also TESTPATHSFIXTURE, REPOSFIXTURE

if nargin < 2
  limits = struct('entries', 5000, 'bytes', 100e6);
end
root = fileparts(mfilename('fullpath')); % tests/fixtures
assert(isfolder(folder), 'Rigbox:tests:rmTestDir:failed', ...
  'Failed to remove test folder %s: it does not exist', folder);
here = cd(folder); full = pwd; cd(here); % absolute, without '..'
inside = strncmpi(full, [root filesep], numel(root) + 1);
assert(inside, 'Rigbox:tests:rmTestDir:outsideFixtures', ...
  'Refusing to delete %s: tests may only delete folders inside %s', full, root);

[nEntries, nBytes, over] = tally(full, limits);
assert(~over, 'Rigbox:tests:rmTestDir:tooBig', ['Refusing to delete %s: it holds ' ...
  'more than %d files and folders or %g MB (counting stopped at %d entries, %.1f MB), ' ...
  'far more than a test makes. Nothing was deleted.'], full, limits.entries, ...
  limits.bytes / 1e6, nEntries, nBytes / 1e6);

assert(rmdir(full, 's'), 'Rigbox:tests:rmTestDir:failed', ...
  'Failed to remove test folder %s', full);
end


function [nEntries, nBytes, over] = tally(folder, limits)
% Stops at the limit, so a huge folder on a network share is refused quickly
nEntries = 0; nBytes = 0; over = false;
pending = {folder};
while ~isempty(pending)
  d = dir(pending{end});
  pending(end) = [];
  d = d(~ismember({d.name}, {'.', '..'}));
  nEntries = nEntries + numel(d);
  nBytes = nBytes + sum([d(~[d.isdir]).bytes]);
  if nEntries > limits.entries || nBytes > limits.bytes
    over = true;
    return
  end
  sub = d([d.isdir]);
  pending = [pending, fullfile({sub.folder}, {sub.name})]; %#ok<AGROW>
end
end
