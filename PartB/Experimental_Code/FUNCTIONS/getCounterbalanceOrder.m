function blockOrder = getCounterbalanceOrder(subjectNumber, condCounts)
% GETCOUNTERBALANCEORDER  Latin-square block order for FLE Experiment 3.
%   blockOrder = getCounterbalanceOrder(subjectNumber, condCounts)
%
%   Returns the presentation order of the experiment's blocks, counterbalanced
%   across participants with a Latin square keyed on the participant ID.
%
%   E3 uses TWO conditions with UNEQUAL block counts:
%       1 = centralcue    (motion baseline)
%       2 = flashbaseline (static flash baseline)
%   so a classical n-condition Latin square does not apply. Instead we:
%     (1) build a fixed "base" sequence whose condition LABELS are correct in
%         number and evenly interleaved (static spaced among motion, never
%         adjacent), then
%     (2) permute the ORDER of those blocks with a balanced (circulant) Latin
%         square, choosing the row by participant. Across a full cycle of
%         numBlocks participants, every base block appears in every session
%         position exactly once, so block order is counterbalanced while the
%         condition counts stay exactly fixed.
%
%   Inputs:
%       subjectNumber - Numeric subject ID (string is converted)
%       condCounts    - [nMotionBlocks nStaticBlocks]
%                       e.g. [12 4] for 24 trials/block, [6 2] for 48/block.
%
%   Output:
%       blockOrder - 1 x (nMotion+nStatic) vector of condition codes
%                    (1 = centralcue, 2 = flashbaseline) in presentation order.

% ---- Parse inputs ----------------------------------------------------
if ischar(subjectNumber) || isstring(subjectNumber)
    subjectNumber = str2double(subjectNumber);
end
if nargin < 2 || isempty(condCounts)
    condCounts = [12 4];   % default: 24 trials/block layout
end
nMotion = condCounts(1);
nStatic = condCounts(2);
nBlocks = nMotion + nStatic;

% ---- (1) Base sequence: correct counts, static spaced & non-adjacent --
baseSeq = ones(1, nBlocks);          % 1 = motion everywhere by default
if nStatic > 0
    % Evenly spaced target positions for the static blocks.
    pos = round(((1:nStatic) - 0.5) * (nBlocks / nStatic));
    pos = min(max(pos, 1), nBlocks);
    used = false(1, nBlocks);
    for k = 1:nStatic
        p = pos(k);
        % resolve collisions / adjacency by walking forward (wrap)
        guard = 0;
        while guard < nBlocks && (used(p) || ...
                (p > 1        && used(p-1)) || ...
                (p < nBlocks  && used(p+1)))
            p = mod(p, nBlocks) + 1;
            guard = guard + 1;
        end
        if used(p)                       % fallback: first free slot
            p = find(~used, 1, 'first');
        end
        used(p) = true;
    end
    baseSeq(used) = 2;                   % mark static slots
end

% ---- (2) Circulant Latin square permutation, row by participant -------
% Row r is a cyclic shift of 0..nBlocks-1; across nBlocks participants this
% is a balanced Latin square (each base block hits each position once).
r = mod(subjectNumber - 1, nBlocks);
perm = mod((0:nBlocks-1) + r, nBlocks) + 1;   % 1-based permutation indices
blockOrder = baseSeq(perm);

% ---- Report ----------------------------------------------------------
conditionNames = {'centralcue', 'flashbaseline'};
fprintf('\n=== BLOCK ORDER (Latin square) FOR SUBJECT %03d ===\n', subjectNumber);
fprintf('(%d blocks: %d motion, %d static)\n', nBlocks, nMotion, nStatic);
for i = 1:nBlocks
    fprintf('Block %2d: %s\n', i, conditionNames{blockOrder(i)});
end
fprintf('==================================================\n\n');
end
