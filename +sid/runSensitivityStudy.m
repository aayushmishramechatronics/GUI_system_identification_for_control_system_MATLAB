function results = runSensitivityStudy(studyType, u, y, Ts, options)
%RUNSENSITIVITYSTUDY Conduct sensitivity experiments on model order, noise, and sampling.
%
%   results = sid.runSensitivityStudy(studyType, u, y, Ts, options)
%   Supports studyType: 'order', 'noise', 'sampling'

    if nargin < 4, error('sid:runSensitivityStudy:nargin', 'At least 4 inputs required.'); end
    if nargin < 5 || isempty(options), options = struct(); end

    u = u(:);
    y = y(:);
    N = numel(u);

    st = lower(char(studyType));
    if contains(st, 'order')
        st = 'order';
    elseif contains(st, 'noise')
        st = 'noise';
    elseif contains(st, 'samp')
        st = 'sampling';
    else
        error('sid:runSensitivityStudy:unknownType', 'Unknown study type: %s', studyType);
    end

    function val = getField(s, names, defaultVal)
        val = defaultVal;
        for nm = names
            if isfield(s, nm{1})
                val = s.(nm{1});
                return;
            end
        end
    end

    switch st
        case 'order'
            nk = getField(options, {'nk'}, 1);
            split = getField(options, {'split', 'estRatio'}, 0.7);
            maxOrder = getField(options, {'maxOrder'}, 5);

            Ne = max(1, round(split * N));
            FitOS  = nan(maxOrder, maxOrder);
            FitFR  = nan(maxOrder, maxOrder);
            FitEst = nan(maxOrder, maxOrder);

            bestFR = -Inf; bestFRna = 1; bestFRnb = 1;
            bestOS = -Inf; bestOSna = 1; bestOSnb = 1;
            bestEst = -Inf; bestEstna = 1; bestEstnb = 1;

            for na = 1:maxOrder
                for nb = 1:maxOrder
                    try
                        m = sid.estimateARX(u, y, na, nb, nk, Ne);
                        ev = sid.evaluateModel(m, u, y, Ne);
                        FitEst(na, nb) = ev.est.fit;
                        FitOS(na, nb)  = ev.valOS.fit;
                        FitFR(na, nb)  = ev.valFR.fit;

                        if isfinite(FitFR(na, nb)) && FitFR(na, nb) > bestFR
                            bestFR = FitFR(na, nb); bestFRna = na; bestFRnb = nb;
                        end
                        if isfinite(FitOS(na, nb)) && FitOS(na, nb) > bestOS
                            bestOS = FitOS(na, nb); bestOSna = na; bestOSnb = nb;
                        end
                        if isfinite(FitEst(na, nb)) && FitEst(na, nb) > bestEst
                            bestEst = FitEst(na, nb); bestEstna = na; bestEstnb = nb;
                        end
                    catch
                        % Keep as NaN
                    end
                end
            end

            results = struct();
            results.type = 'order';
            results.nk = nk;
            results.split = split;
            results.maxOrder = maxOrder;
            results.FitOS = FitOS;
            results.FitFR = FitFR;
            results.FitEst = FitEst;
            results.bestFR = bestFR;
            results.bestFRna = bestFRna;
            results.bestFRnb = bestFRnb;
            results.bestOS = bestOS;
            results.bestOSna = bestOSna;
            results.bestOSnb = bestOSnb;
            results.bestEstna = bestEstna;
            results.bestEstnb = bestEstnb;

        case 'noise'
            na = getField(options, {'na'}, 2);
            nb = getField(options, {'nb'}, 2);
            nk = getField(options, {'nk'}, 1);
            split = getField(options, {'split', 'estRatio'}, 0.7);
            noisePct = getField(options, {'noisePct'}, 0);
            seed = getField(options, {'seed'}, 1);
            levels = getField(options, {'levels'}, [0 20 50]);

            Ne = max(1, round(split * N));

            base = sid.estimateARX(u, y, na, nb, nk, Ne);
            evBase = sid.evaluateModel(base, u, y, Ne);

            stdEstY = std(y(1:Ne));
            try
                rng(seed, 'twister');
                rawNoise = randn(Ne, 1);
            catch
                randn('state', seed); %#ok<RAND>
                rawNoise = randn(Ne, 1);
            end

            if noisePct == 0
                noise = zeros(Ne, 1);
            else
                noise = (noisePct / 100) * stdEstY * rawNoise;
            end

            yNoisy = y;
            yNoisy(1:Ne) = y(1:Ne) + noise;

            noisy = sid.estimateARX(u, yNoisy, na, nb, nk, Ne);
            evNoisy = sid.evaluateModel(noisy, u, y, Ne);

            % Sweep over levels
            nLev = numel(levels);
            sweepOS = nan(nLev, 1);
            sweepFR = nan(nLev, 1);

            for i = 1:nLev
                lvl = levels(i);
                if lvl == 0
                    lvlNoise = zeros(Ne, 1);
                else
                    lvlNoise = (lvl / 100) * stdEstY * rawNoise;
                end
                yL = y;
                yL(1:Ne) = y(1:Ne) + lvlNoise;
                try
                    mL = sid.estimateARX(u, yL, na, nb, nk, Ne);
                    evL = sid.evaluateModel(mL, u, y, Ne);
                    sweepOS(i) = evL.valOS.fit;
                    sweepFR(i) = evL.valFR.fit;
                catch
                    % NaN
                end
            end

            results = struct();
            results.type = 'noise';
            results.pct = noisePct;
            results.seed = seed;
            results.Ne = Ne;
            results.base = base;
            results.noisy = noisy;
            results.evBase = evBase;
            results.evNoisy = evNoisy;
            results.yNoisy = yNoisy;
            results.levels = levels;
            results.sweepOS = sweepOS;
            results.sweepFR = sweepFR;

        case 'sampling'
            na = getField(options, {'na'}, 2);
            nb = getField(options, {'nb'}, 2);
            nk = getField(options, {'nk'}, 1);
            split = getField(options, {'split', 'estRatio'}, 0.7);
            factors = getField(options, {'factors'}, [1 2 4]);
            t = getField(options, {'t'}, (0:N-1)' * Ts);

            nFact = numel(factors);
            TsArr = zeros(nFact, 1);
            NArr  = zeros(nFact, 1);
            FitOS = nan(nFact, 1);
            FitFR = nan(nFact, 1);
            Note  = cell(nFact, 1);

            for i = 1:nFact
                f = factors(i);
                Tsn = Ts * f;
                TsArr(i) = Tsn;
                try
                    [tn, un, yn] = sid.resampleUniform(t, u, y, Tsn);
                    Nn = numel(yn);
                    NArr(i) = Nn;
                    Nen = max(1, round(split * Nn));
                    mn = sid.estimateARX(un, yn, na, nb, nk, Nen);
                    evn = sid.evaluateModel(mn, un, yn, Nen);
                    FitOS(i) = evn.valOS.fit;
                    FitFR(i) = evn.valFR.fit;
                    Note{i} = 'OK';
                catch ME
                    NArr(i) = 0;
                    Note{i} = ME.message;
                end
            end

            results = struct();
            results.type = 'sampling';
            results.Ts = TsArr;
            results.N = NArr;
            results.FitOS = FitOS;
            results.FitFR = FitFR;
            results.Note = Note;
            results.factors = factors;
    end
end
