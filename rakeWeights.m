function w = rakeWeights(catVars, N)
% RAKEWEIGHTS  Compute calibration / raking weights so that
% sample margins match target population shares.
%
% INPUT:
%   catVars - K x 2 cell array:
%             { var1, targetShare1;
%               var2, targetShare2;
%               ...
%               varK, targetShareK }
%             where varj is an N x 1 integer vector with category codes
%             (1..Cj), and targetSharej is a Cj x 1 vector summing to 1.
%
%   N       - number of respondents (length of each varj)
%
% OUTPUT:
%   w       - N x 1 vector of respondent-specific calibration weights,
%             normalised so that mean(w) = 1 (sum(w) = N).
%
% Method: iterative proportional fitting (raking) over margins.

    K = size(catVars,1);         % number of margins
    w = ones(N,1);               % start with equal weights

    maxIter = 5000;
    tol     = 1e-6;

    for it = 1:maxIter
        maxDiff = 0;

        for k = 1:K

            var_k    = catVars{k,1};
            target_k = catVars{k,2};

            cats = unique(var_k(~isnan(var_k)));
            Ck   = numel(cats);

            if Ck ~= numel(target_k)
                error('rakeWeights: length(targetShare) for margin %d does not match number of categories in data.', k);
            end

            % Adjust weights category by category
            for c = 1:Ck
                catCode = cats(c);
                idx_c   = (var_k == catCode);

                if ~any(idx_c)
                    % No observations in this category – skip (or handle separately)
                    continue;
                end

                % Current weighted total for category c
                currentTotal = sum(w(idx_c));

                if currentTotal <= 0
                    continue;
                end

                % Desired total for this category (weights sum to N)
                desiredTotal = target_k(c) * N;

                factor = desiredTotal / currentTotal;
                w(idx_c) = w(idx_c) * factor;
            end

            % Check convergence on this margin
            for c = 1:Ck
                catCode = cats(c);
                idx_c   = (var_k == catCode);
                if ~any(idx_c)
                    continue;
                end
                share_now = sum(w(idx_c)) / sum(w);
                diff_c    = abs(share_now - target_k(c));
                if diff_c > maxDiff
                    maxDiff = diff_c;
                end
            end
        end

        if maxDiff < tol
            % Converged
            fprintf('rakeWeights: converged in %d iterations, max margin diff = %.2e\n', it, maxDiff);
            break;
        end

        if it == maxIter
            warning('rakeWeights: maximum iterations reached, max margin diff = %.2e', maxDiff);
        end
    end

    % Normalise weights so that mean(w) = 1 (sum(w) = N)
    w = w * (N / sum(w));
end
